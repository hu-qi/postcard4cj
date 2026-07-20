use serde::{Deserialize, Serialize};

#[derive(Debug, PartialEq, Serialize, Deserialize)]
struct MacroRecord {
    id: u32,
    delta: i32,
    note: Option<String>,
    values: Vec<u16>,
}

#[derive(Debug, PartialEq, Serialize, Deserialize)]
struct MacroWide {
    unsigned: u128,
    signed: i128,
}

#[derive(Debug, PartialEq, Serialize, Deserialize)]
enum MacroCommand {
    Ping,
    SetSpeed(u16),
    Rename(String, bool),
}

#[test]
fn struct_vector_matches_cangjie_macro_test() {
    let value = MacroRecord {
        id: 42,
        delta: -1,
        note: Some("Hi".to_owned()),
        values: vec![1, 128],
    };

    let expected = [
        0x2A, 0x01, 0x01, 0x02, 0x48, 0x69, 0x02, 0x01, 0x80, 0x01,
    ];
    let bytes = postcard::to_allocvec(&value).expect("serialize MacroRecord");
    assert_eq!(bytes, expected);
    assert_eq!(
        postcard::from_bytes::<MacroRecord>(&bytes).expect("deserialize MacroRecord"),
        value
    );
}

#[test]
fn typed_int128_wrapper_vector_matches_rust_fields() {
    let value = MacroWide {
        unsigned: 128,
        signed: -1,
    };
    let expected = [0x80, 0x01, 0x01];

    let bytes = postcard::to_allocvec(&value).expect("serialize MacroWide");
    assert_eq!(bytes, expected);
    assert_eq!(
        postcard::from_bytes::<MacroWide>(&bytes).expect("deserialize MacroWide"),
        value
    );
}

#[test]
fn enum_vectors_use_declaration_order() {
    let cases = [
        (MacroCommand::Ping, vec![0x00]),
        (MacroCommand::SetSpeed(128), vec![0x01, 0x80, 0x01]),
        (
            MacroCommand::Rename("Hi".to_owned(), true),
            vec![0x02, 0x02, 0x48, 0x69, 0x01],
        ),
    ];

    for (value, expected) in cases {
        let bytes = postcard::to_allocvec(&value).expect("serialize MacroCommand");
        assert_eq!(bytes, expected);
        assert_eq!(
            postcard::from_bytes::<MacroCommand>(&bytes).expect("deserialize MacroCommand"),
            value
        );
    }
}
