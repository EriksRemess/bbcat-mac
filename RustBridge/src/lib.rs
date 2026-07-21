use std::{
    cell::RefCell,
    ffi::{CStr, CString, c_char},
    path::Path,
    ptr,
    time::Duration,
};

mod thumbnail;

thread_local! {
    static LAST_ERROR: RefCell<Option<String>> = const { RefCell::new(None) };
}

pub struct BbcatDocument {
    document: bbcat::Document,
}

#[repr(C)]
pub struct BbcatFrame {
    pub data: *mut u8,
    pub length: usize,
    pub duration_ns: u64,
}

fn set_error(error: impl ToString) {
    LAST_ERROR.with(|slot| *slot.borrow_mut() = Some(error.to_string()));
}

fn c_string(value: impl AsRef<str>) -> *mut c_char {
    let clean = value.as_ref().replace('\0', "");
    CString::new(clean)
        .expect("interior NULs were removed")
        .into_raw()
}

fn input_string<'a>(value: *const c_char, name: &str) -> Result<&'a str, String> {
    if value.is_null() {
        return Err(format!("{name} was null"));
    }
    // SAFETY: Callers must provide a live, NUL-terminated C string.
    unsafe { CStr::from_ptr(value) }
        .to_str()
        .map_err(|_| format!("{name} is not valid UTF-8"))
}

fn non_empty(value: &str) -> Option<&str> {
    let value = value.trim();
    (!value.is_empty()).then_some(value)
}

fn format_sauce_date(date: &str) -> String {
    if date.len() == 8 && date.bytes().all(|byte| byte.is_ascii_digit()) {
        format!("{}-{}-{}", &date[..4], &date[4..6], &date[6..])
    } else {
        date.to_owned()
    }
}

fn frame_duration(frame: &bbcat::AnimationFrame) -> Duration {
    frame.duration.unwrap_or_else(|| {
        let nanoseconds = (frame.source_bytes as u128).saturating_mul(1_000_000_000)
            / u128::from(bbcat::DEFAULT_ANIMATION_BAUD);
        Duration::from_nanos(nanoseconds.min(u128::from(u64::MAX)) as u64)
    })
}

#[unsafe(no_mangle)]
pub extern "C" fn bbcat_document_open(path: *const c_char) -> *mut BbcatDocument {
    let result = (|| {
        let path = Path::new(input_string(path, "path")?);
        let data = std::fs::read(path).map_err(|error| error.to_string())?;
        let document = bbcat::decode_with_options(
            &data,
            bbcat::DecodeOptions {
                file_name: Some(path),
                width: None,
            },
        )
        .map_err(|error| error.to_string())?;
        Ok::<_, String>(Box::into_raw(Box::new(BbcatDocument { document })))
    })();
    match result {
        Ok(document) => document,
        Err(error) => {
            set_error(error);
            ptr::null_mut()
        }
    }
}

#[unsafe(no_mangle)]
/// Releases a document returned by [`bbcat_document_open`].
///
/// # Safety
///
/// `document` must be null or a live pointer returned by
/// [`bbcat_document_open`] that has not already been freed.
pub unsafe extern "C" fn bbcat_document_free(document: *mut BbcatDocument) {
    if !document.is_null() {
        // SAFETY: The pointer came from Box::into_raw in bbcat_document_open and
        // ownership is transferred to this function exactly once.
        drop(unsafe { Box::from_raw(document) });
    }
}

#[unsafe(no_mangle)]
/// Returns the number of renderable frames in a document.
///
/// # Safety
///
/// `document` must be null or a live pointer returned by
/// [`bbcat_document_open`].
pub unsafe extern "C" fn bbcat_document_frame_count(document: *const BbcatDocument) -> usize {
    if document.is_null() {
        return 0;
    }
    // SAFETY: A non-null document pointer is owned by the caller for this call.
    let document = unsafe { &(*document).document };
    document
        .animation
        .as_ref()
        .map_or(1, |animation| animation.frames.len().max(1))
}

#[unsafe(no_mangle)]
/// Creates the display title, including available SAUCE metadata.
///
/// # Safety
///
/// `document` must point to a live document and `fallback` must point to a
/// live, NUL-terminated string for the duration of the call. The returned
/// string must be released with [`bbcat_string_free`].
pub unsafe extern "C" fn bbcat_document_display_title(
    document: *const BbcatDocument,
    fallback: *const c_char,
) -> *mut c_char {
    if document.is_null() {
        set_error("document was null");
        return ptr::null_mut();
    }
    let fallback = input_string(fallback, "fallback").unwrap_or("ANSI art");
    // SAFETY: A non-null document pointer is owned by the caller for this call.
    let document = unsafe { &(*document).document };
    let (title, details) = document.sauce.as_ref().map_or_else(
        || (fallback.to_owned(), Vec::new()),
        |sauce| {
            let title = non_empty(&sauce.title).unwrap_or(fallback).to_owned();
            let mut details = Vec::new();
            if let Some(author) = non_empty(&sauce.author) {
                details.push(format!("by {author}"));
            }
            if let Some(date) = non_empty(&sauce.date) {
                details.push(format_sauce_date(date));
            }
            (title, details)
        },
    );
    if details.is_empty() {
        c_string(title)
    } else {
        c_string(format!("{title} — {}", details.join(" · ")))
    }
}

#[unsafe(no_mangle)]
/// Renders one document frame as PNG bytes.
///
/// # Safety
///
/// `document` must point to a live document and `output` must point to writable
/// `BbcatFrame` storage. Successful output bytes must be released once with
/// [`bbcat_bytes_free`] using the returned length.
pub unsafe extern "C" fn bbcat_document_render_frame(
    document: *const BbcatDocument,
    index: usize,
    scale: usize,
    output: *mut BbcatFrame,
) -> i32 {
    if document.is_null() || output.is_null() {
        set_error("document or output was null");
        return 0;
    }
    // SAFETY: Both non-null pointers remain valid for this call.
    let document = unsafe { &(*document).document };
    let result =
        if let Some(animation) = document.animation.as_ref().filter(|a| !a.frames.is_empty()) {
            animation
                .frames
                .get(index)
                .ok_or_else(|| "frame index is out of range".to_owned())
                .and_then(|frame| {
                    bbcat::encode_screen_scaled(&frame.screen, 0, frame.screen.height, scale)
                        .map(|png| (png, frame_duration(frame)))
                        .map_err(|error| error.to_string())
                })
        } else if index == 0 {
            document
                .encode_png(scale)
                .map(|png| (png, Duration::ZERO))
                .map_err(|error| error.to_string())
        } else {
            Err("frame index is out of range".to_owned())
        };

    match result {
        Ok((png, duration)) => {
            let mut png = png.into_boxed_slice();
            let frame = BbcatFrame {
                data: png.as_mut_ptr(),
                length: png.len(),
                duration_ns: duration.as_nanos().min(u128::from(u64::MAX)) as u64,
            };
            std::mem::forget(png);
            // SAFETY: output is non-null and points to writable BbcatFrame storage.
            unsafe { output.write(frame) };
            1
        }
        Err(error) => {
            set_error(error);
            0
        }
    }
}

#[unsafe(no_mangle)]
/// Renders a square, top-left-anchored PNG thumbnail.
///
/// # Safety
///
/// `document` must point to a live document and `output` must point to writable
/// `BbcatFrame` storage. Successful output bytes must be released once with
/// [`bbcat_bytes_free`] using the returned length.
pub unsafe extern "C" fn bbcat_document_render_thumbnail(
    document: *const BbcatDocument,
    maximum_pixel_size: usize,
    output: *mut BbcatFrame,
) -> i32 {
    if document.is_null() || output.is_null() {
        set_error("document or output was null");
        return 0;
    }
    // SAFETY: Both non-null pointers remain valid for this call.
    let document = unsafe { &(*document).document };
    match thumbnail::encode_thumbnail(&document.screen, maximum_pixel_size) {
        Ok(png) => {
            let mut png = png.into_boxed_slice();
            let frame = BbcatFrame {
                data: png.as_mut_ptr(),
                length: png.len(),
                duration_ns: 0,
            };
            std::mem::forget(png);
            // SAFETY: output points to writable BbcatFrame storage.
            unsafe { output.write(frame) };
            1
        }
        Err(error) => {
            set_error(error);
            0
        }
    }
}

#[unsafe(no_mangle)]
/// Renders the app's ANSI-art welcome message with bbcat's built-in VGA font.
///
/// # Safety
///
/// `output` must point to writable [`BbcatFrame`] storage. Successful output
/// bytes must be released once with [`bbcat_bytes_free`] using the returned
/// length.
pub unsafe extern "C" fn bbcat_render_welcome(scale: usize, output: *mut BbcatFrame) -> i32 {
    if output.is_null() {
        set_error("output was null");
        return 0;
    }

    let ansi = concat!(
        "\x1b[97mopen an artwork to view it\r\n\r\n",
        "\x1b[90m          cmd-o\x1b[0m"
    );
    let result = bbcat::decode_with_options(
        ansi.as_bytes(),
        bbcat::DecodeOptions {
            file_name: None,
            width: Some(26),
        },
    )
    .and_then(|document| document.encode_png(scale));

    match result {
        Ok(png) => {
            let mut png = png.into_boxed_slice();
            let frame = BbcatFrame {
                data: png.as_mut_ptr(),
                length: png.len(),
                duration_ns: 0,
            };
            std::mem::forget(png);
            // SAFETY: output is non-null and points to writable BbcatFrame storage.
            unsafe { output.write(frame) };
            1
        }
        Err(error) => {
            set_error(error);
            0
        }
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn bbcat_take_last_error() -> *mut c_char {
    LAST_ERROR.with(|slot| slot.borrow_mut().take().map_or(ptr::null_mut(), c_string))
}

#[unsafe(no_mangle)]
/// Releases a string allocated by this library.
///
/// # Safety
///
/// `string` must be null or a pointer returned by a bridge string function
/// that has not already been freed.
pub unsafe extern "C" fn bbcat_string_free(string: *mut c_char) {
    if !string.is_null() {
        // SAFETY: The pointer was allocated with CString::into_raw by this library.
        drop(unsafe { CString::from_raw(string) });
    }
}

#[unsafe(no_mangle)]
/// Releases a PNG byte buffer allocated by this library.
///
/// # Safety
///
/// `data` and `length` must be the unchanged pair returned in a successful
/// `BbcatFrame`, and the buffer must not already have been freed.
pub unsafe extern "C" fn bbcat_bytes_free(data: *mut u8, length: usize) {
    if !data.is_null() {
        // SAFETY: PNG buffers are returned as boxed slices and ownership is
        // transferred back exactly once with the original length.
        let slice = ptr::slice_from_raw_parts_mut(data, length);
        drop(unsafe { Box::from_raw(slice) });
    }
}

#[cfg(test)]
mod tests {
    use super::format_sauce_date;

    #[test]
    fn formats_sauce_dates() {
        assert_eq!(format_sauce_date("20260720"), "2026-07-20");
        assert_eq!(format_sauce_date("unknown"), "unknown");
    }
}
