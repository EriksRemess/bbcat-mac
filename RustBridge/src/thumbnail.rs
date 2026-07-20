use bbcat::Screen;

const MAX_THUMBNAIL_SIZE: usize = 1024;

pub fn encode_thumbnail(screen: &Screen, maximum_size: usize) -> Result<Vec<u8>, String> {
    let maximum_size = maximum_size.min(MAX_THUMBNAIL_SIZE);
    if maximum_size == 0 {
        return Err("thumbnail size must be non-zero".to_owned());
    }
    let (source_width, source_height) = screen
        .pixel_dimensions()
        .ok_or("rendered image dimensions overflow")?;
    if source_width == 0 || source_height == 0 {
        return Err("rendered image is empty".to_owned());
    }

    // Match bbcat-thumbnailer: Finder icons show the beginning of long/wide
    // artwork instead of shrinking the entire canvas into an unreadable strip.
    let crop_size = source_width.min(source_height);
    let target_size = crop_size.min(maximum_size);
    let scanline_length = 1_usize
        .checked_add(target_size.checked_mul(3).ok_or("PNG row size overflow")?)
        .ok_or("PNG row size overflow")?;
    let mut scanlines = Vec::with_capacity(
        target_size
            .checked_mul(scanline_length)
            .ok_or("PNG buffer size overflow")?,
    );

    for y in 0..target_size {
        scanlines.push(0); // PNG filter: None
        let source_y = scaled_coordinate(y, crop_size, target_size);
        for x in 0..target_size {
            let source_x = scaled_coordinate(x, crop_size, target_size);
            scanlines.extend_from_slice(&pixel_color(screen, source_x, source_y)?);
        }
    }

    Ok(rgb_png(target_size, target_size, &scanlines))
}
fn scaled_coordinate(position: usize, source_length: usize, target_length: usize) -> usize {
    ((position as u128 * source_length as u128) / target_length as u128) as usize
}

fn pixel_color(screen: &Screen, x: usize, y: usize) -> Result<[u8; 3], String> {
    if let Some(raster) = screen.raster() {
        let index = y
            .checked_mul(raster.width)
            .and_then(|offset| offset.checked_add(x))
            .and_then(|offset| raster.pixels.get(offset))
            .ok_or("raster pixel is outside the rendered image")?;
        return Ok(screen.color(*index));
    }

    let (glyph_width, glyph_height) = screen.glyph_dimensions();
    let cell = screen
        .cell(x / glyph_width, y / glyph_height)
        .ok_or("character pixel is outside the rendered image")?;
    let glyph_row = y % glyph_height;
    let glyph_offset = usize::from(cell.character)
        .checked_mul(glyph_height)
        .and_then(|offset| offset.checked_add(glyph_row))
        .ok_or("font glyph index overflow")?;
    let bits = screen
        .font()
        .and_then(|font| font.get(glyph_offset))
        .ok_or("character references a missing font glyph")?;
    let glyph_x = x % glyph_width;
    let foreground = match glyph_x {
        0..=7 => bits & (0x80 >> glyph_x) != 0,
        8 if (0xc0..=0xdf).contains(&cell.character) => bits & 1 != 0,
        _ => false,
    };
    Ok(screen.color(if foreground {
        cell.foreground
    } else {
        cell.background
    }))
}

fn rgb_png(width: usize, height: usize, scanlines: &[u8]) -> Vec<u8> {
    let mut png = b"\x89PNG\r\n\x1a\n".to_vec();
    let mut ihdr = Vec::with_capacity(13);
    ihdr.extend_from_slice(&(width as u32).to_be_bytes());
    ihdr.extend_from_slice(&(height as u32).to_be_bytes());
    ihdr.extend_from_slice(&[8, 2, 0, 0, 0]);
    chunk(&mut png, b"IHDR", &ihdr);
    chunk(&mut png, b"IDAT", &zlib_store(scanlines));
    chunk(&mut png, b"IEND", &[]);
    png
}

fn zlib_store(data: &[u8]) -> Vec<u8> {
    let mut output = Vec::with_capacity(data.len() + data.len() / 65_535 * 5 + 11);
    output.extend_from_slice(&[0x78, 0x01]);
    if data.is_empty() {
        output.extend_from_slice(&[1, 0, 0, 0xff, 0xff]);
    } else {
        for (index, block) in data.chunks(65_535).enumerate() {
            output.push(u8::from(index + 1 == data.len().div_ceil(65_535)));
            let length = block.len() as u16;
            output.extend_from_slice(&length.to_le_bytes());
            output.extend_from_slice(&(!length).to_le_bytes());
            output.extend_from_slice(block);
        }
    }
    output.extend_from_slice(&adler32(data).to_be_bytes());
    output
}

fn adler32(data: &[u8]) -> u32 {
    let (mut a, mut b) = (1_u32, 0_u32);
    for &byte in data {
        a = (a + u32::from(byte)) % 65_521;
        b = (b + a) % 65_521;
    }
    (b << 16) | a
}

fn chunk(output: &mut Vec<u8>, kind: &[u8; 4], data: &[u8]) {
    output.extend_from_slice(&(data.len() as u32).to_be_bytes());
    output.extend_from_slice(kind);
    output.extend_from_slice(data);
    let mut crc_input = Vec::with_capacity(4 + data.len());
    crc_input.extend_from_slice(kind);
    crc_input.extend_from_slice(data);
    output.extend_from_slice(&crc32(&crc_input).to_be_bytes());
}

fn crc32(data: &[u8]) -> u32 {
    let mut crc = 0xffff_ffff_u32;
    for &byte in data {
        crc ^= u32::from(byte);
        for _ in 0..8 {
            crc = (crc >> 1) ^ (0xedb8_8320 & 0_u32.wrapping_sub(crc & 1));
        }
    }
    !crc
}

#[cfg(test)]
mod tests {
    use super::encode_thumbnail;
    use std::path::Path;

    #[test]
    fn scales_and_crops_character_art() {
        let document = bbcat::decode_with_options(
            b"ABCDEFGHIJ\r\n0123456789",
            bbcat::DecodeOptions {
                file_name: Some(Path::new("drawing.ans")),
                width: Some(10),
            },
        )
        .unwrap();
        let png = encode_thumbnail(&document.screen, 16).unwrap();
        assert_eq!(&png[..8], b"\x89PNG\r\n\x1a\n");
        assert_eq!(u32::from_be_bytes(png[16..20].try_into().unwrap()), 16);
        assert_eq!(u32::from_be_bytes(png[20..24].try_into().unwrap()), 16);
    }
}
