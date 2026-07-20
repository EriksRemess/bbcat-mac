use std::{ffi::CString, path::PathBuf};

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
        bbcat_bridge::bbcat_bytes_free(thumbnail.data, thumbnail.length);
        bbcat_bridge::bbcat_document_free(document);
    }
}
