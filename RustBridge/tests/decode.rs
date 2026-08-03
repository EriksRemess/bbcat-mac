use std::{
    ffi::{CStr, CString},
    mem::MaybeUninit,
    path::PathBuf,
};

#[test]
fn decodes_and_renders_ansi_through_the_c_api() {
    let path = PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("tests/fixtures/basic.ans");
    let path = CString::new(path.to_string_lossy().as_bytes()).unwrap();
    let document = bbcat_bridge::bbcat_document_open(path.as_ptr());
    assert!(!document.is_null());
    assert_eq!(
        unsafe { bbcat_bridge::bbcat_document_frame_count(document) },
        1
    );
    assert_eq!(
        unsafe { bbcat_bridge::bbcat_document_is_animated(document) },
        0
    );
    assert_eq!(
        unsafe { bbcat_bridge::bbcat_document_supports_scale(document, 2) },
        1
    );

    let mut frame = bbcat_bridge::BbcatFrame {
        data: std::ptr::null_mut(),
        length: 0,
        duration_ns: 0,
    };
    assert_eq!(
        unsafe { bbcat_bridge::bbcat_document_render_frame(document, 0, 1, &mut frame) },
        1
    );
    assert!(frame.length > 8);
    let signature = unsafe { std::slice::from_raw_parts(frame.data, 8) };
    assert_eq!(signature, b"\x89PNG\r\n\x1a\n");

    let mut exported = bbcat_bridge::BbcatFrame {
        data: std::ptr::null_mut(),
        length: 0,
        duration_ns: 0,
    };
    assert_eq!(
        unsafe { bbcat_bridge::bbcat_document_encode_png(document, 1, &mut exported) },
        1
    );
    assert_eq!(
        unsafe { std::slice::from_raw_parts(exported.data, 8) },
        b"\x89PNG\r\n\x1a\n"
    );

    let mut thumbnail = bbcat_bridge::BbcatFrame {
        data: std::ptr::null_mut(),
        length: 0,
        duration_ns: 0,
    };
    assert_eq!(
        unsafe { bbcat_bridge::bbcat_document_render_thumbnail(document, 128, &mut thumbnail) },
        1
    );
    assert_eq!(
        unsafe { std::slice::from_raw_parts(thumbnail.data, 8) },
        b"\x89PNG\r\n\x1a\n"
    );

    unsafe {
        bbcat_bridge::bbcat_bytes_free(frame.data, frame.length);
        bbcat_bridge::bbcat_bytes_free(exported.data, exported.length);
        bbcat_bridge::bbcat_bytes_free(thumbnail.data, thumbnail.length);
        bbcat_bridge::bbcat_document_free(document);
    }
}

#[test]
fn reports_animation_info_through_the_c_api() {
    let path = PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("tests/fixtures/animated.ddw");
    let path = CString::new(path.to_string_lossy().as_bytes()).unwrap();
    let document = bbcat_bridge::bbcat_document_open(path.as_ptr());
    assert!(!document.is_null());
    assert_eq!(
        unsafe { bbcat_bridge::bbcat_document_is_animated(document) },
        1
    );
    assert_eq!(
        unsafe { bbcat_bridge::bbcat_document_frame_count(document) },
        2
    );

    let mut info = MaybeUninit::<bbcat_bridge::BbcatDocumentInfo>::uninit();
    assert_eq!(
        unsafe { bbcat_bridge::bbcat_document_copy_info(document, info.as_mut_ptr()) },
        1
    );
    let info = unsafe { info.assume_init() };
    assert_eq!((info.columns, info.rows), (1, 1));
    assert_eq!(info.animated, 1);
    assert_eq!(info.frame_count, 2);

    let mut gif = bbcat_bridge::BbcatFrame {
        data: std::ptr::null_mut(),
        length: 0,
        duration_ns: 0,
    };
    assert_eq!(
        unsafe { bbcat_bridge::bbcat_document_encode_gif(document, 1, &mut gif) },
        1
    );
    let gif_bytes = unsafe { std::slice::from_raw_parts(gif.data, gif.length) };
    assert_eq!(&gif_bytes[..6], b"GIF89a");
    assert_eq!(
        gif_bytes
            .windows(2)
            .filter(|bytes| *bytes == b"\x21\xf9")
            .count(),
        2
    );

    let format = unsafe { bbcat_bridge::bbcat_document_copy_metadata_string(document, 0) };
    assert!(!format.is_null());
    assert_eq!(
        unsafe { CStr::from_ptr(format) }.to_str().unwrap(),
        "DarkDraw DDW"
    );

    unsafe {
        bbcat_bridge::bbcat_bytes_free(gif.data, gif.length);
        bbcat_bridge::bbcat_string_free(format);
        bbcat_bridge::bbcat_document_free(document);
    }
}

#[test]
fn renders_welcome_artwork_through_the_c_api() {
    let mut frame = bbcat_bridge::BbcatFrame {
        data: std::ptr::null_mut(),
        length: 0,
        duration_ns: 0,
    };
    assert_eq!(
        unsafe { bbcat_bridge::bbcat_render_welcome(1, &mut frame) },
        1
    );
    assert!(frame.length > 8);
    assert_eq!(
        unsafe { std::slice::from_raw_parts(frame.data, 8) },
        b"\x89PNG\r\n\x1a\n"
    );
    let png = unsafe { std::slice::from_raw_parts(frame.data, frame.length) };
    assert_eq!(u32::from_be_bytes(png[16..20].try_into().unwrap()), 26 * 8);
    assert_eq!(u32::from_be_bytes(png[20..24].try_into().unwrap()), 3 * 16);
    unsafe { bbcat_bridge::bbcat_bytes_free(frame.data, frame.length) };
}
