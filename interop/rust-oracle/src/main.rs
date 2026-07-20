use crc::{Crc, CRC_32_ISCSI};
use serde::{Deserialize, Serialize};

#[derive(Debug, PartialEq, Serialize, Deserialize)]
struct Record {
    id: u32,
    delta: i32,
    active: bool,
    name: String,
}

#[derive(Debug, PartialEq, Serialize, Deserialize)]
struct Telemetry {
    id: u32,
    temperature: f32,
    note: Option<String>,
    samples: Vec<i16>,
}

#[derive(Debug, PartialEq, Serialize, Deserialize)]
enum Mode {
    Idle,
    Active(u16),
}

#[derive(Debug, PartialEq, Serialize, Deserialize)]
struct Compound {
    marker: char,
    unit: (),
    pair: (u8, i16),
    entries: Vec<(u8, String)>,
    mode: Mode,
}

#[derive(Debug, PartialEq, Serialize, Deserialize)]
struct WideValues {
    unsigned_maximum: u128,
    signed_minimum: i128,
    signed_sample: i128,
}

fn hex(bytes: &[u8]) -> String {
    bytes
        .iter()
        .map(|byte| format!("{byte:02X}"))
        .collect::<Vec<_>>()
        .join(" ")
}

fn main() {
    let record = Record {
        id: 42,
        delta: -1,
        active: true,
        name: "Hi".to_owned(),
    };

    let record_bytes = postcard::to_allocvec(&record).expect("serialize Record");
    assert_eq!(record_bytes, [0x2A, 0x01, 0x01, 0x02, 0x48, 0x69]);

    let decoded_record: Record =
        postcard::from_bytes(&record_bytes).expect("deserialize Record");
    assert_eq!(decoded_record, record);

    let telemetry = Telemetry {
        id: 300,
        temperature: 12.5,
        note: Some("ok".to_owned()),
        samples: vec![-1, 0, 1, 128],
    };

    let telemetry_bytes = postcard::to_allocvec(&telemetry).expect("serialize Telemetry");
    assert_eq!(
        telemetry_bytes,
        [
            0xAC, 0x02, 0x00, 0x00, 0x48, 0x41, 0x01, 0x02, 0x6F, 0x6B, 0x04, 0x01,
            0x00, 0x02, 0x80, 0x02,
        ]
    );

    let decoded_telemetry: Telemetry =
        postcard::from_bytes(&telemetry_bytes).expect("deserialize Telemetry");
    assert_eq!(decoded_telemetry, telemetry);

    let telemetry_cobs =
        postcard::to_allocvec_cobs(&telemetry).expect("serialize COBS Telemetry");
    assert_eq!(
        telemetry_cobs,
        [
            0x03, 0xAC, 0x02, 0x01, 0x09, 0x48, 0x41, 0x01, 0x02, 0x6F, 0x6B, 0x04,
            0x01, 0x04, 0x02, 0x80, 0x02, 0x00,
        ]
    );
    let mut telemetry_cobs_for_decode = telemetry_cobs.clone();
    let decoded_cobs_telemetry: Telemetry =
        postcard::from_bytes_cobs(&mut telemetry_cobs_for_decode)
            .expect("deserialize COBS Telemetry");
    assert_eq!(decoded_cobs_telemetry, telemetry);

    let crc = Crc::<u32>::new(&CRC_32_ISCSI);
    let telemetry_crc = postcard::to_allocvec_crc32(&telemetry, crc.digest())
        .expect("serialize CRC32 Telemetry");
    assert_eq!(
        telemetry_crc,
        [
            0xAC, 0x02, 0x00, 0x00, 0x48, 0x41, 0x01, 0x02, 0x6F, 0x6B, 0x04, 0x01,
            0x00, 0x02, 0x80, 0x02, 0xAE, 0xB6, 0xF9, 0xB6,
        ]
    );
    let decoded_crc_telemetry: Telemetry =
        postcard::from_bytes_crc32(&telemetry_crc, crc.digest())
            .expect("deserialize CRC32 Telemetry");
    assert_eq!(decoded_crc_telemetry, telemetry);

    let compound = Compound {
        marker: '爱',
        unit: (),
        pair: (7, -1),
        entries: vec![(1, "a".to_owned()), (2, "b".to_owned())],
        mode: Mode::Active(128),
    };

    let compound_bytes = postcard::to_allocvec(&compound).expect("serialize Compound");
    assert_eq!(
        compound_bytes,
        [
            0x03, 0xE7, 0x88, 0xB1, 0x07, 0x01, 0x02, 0x01, 0x01, 0x61, 0x02, 0x01,
            0x62, 0x01, 0x80, 0x01,
        ]
    );

    let decoded_compound: Compound =
        postcard::from_bytes(&compound_bytes).expect("deserialize Compound");
    assert_eq!(decoded_compound, compound);

    let wide = WideValues {
        unsigned_maximum: u128::MAX,
        signed_minimum: i128::MIN,
        signed_sample: -19490127978232325886905073712831_i128,
    };
    let wide_bytes = postcard::to_allocvec(&wide).expect("serialize WideValues");
    assert_eq!(
        wide_bytes,
        [
            0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
            0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0x03,
            0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
            0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0x03,
            0xFD, 0xFA, 0xF5, 0xEB, 0xF7, 0xFF, 0xFF, 0xFF, 0xFF, 0xC3, 0xFF, 0xFF,
            0xFF, 0xFF, 0x7A,
        ]
    );
    let decoded_wide: WideValues =
        postcard::from_bytes(&wide_bytes).expect("deserialize WideValues");
    assert_eq!(decoded_wide, wide);

    println!("Record:          {}", hex(&record_bytes));
    println!("Telemetry:       {}", hex(&telemetry_bytes));
    println!("Telemetry COBS:  {}", hex(&telemetry_cobs));
    println!("Telemetry CRC32: {}", hex(&telemetry_crc));
    println!("Compound:        {}", hex(&compound_bytes));
    println!("WideValues:      {}", hex(&wide_bytes));
}
