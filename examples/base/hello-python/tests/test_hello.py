from hello import greeting


def test_greeting():
    assert greeting() == "Hello, world!"
    assert greeting("eCTF") == "Hello, eCTF!"
