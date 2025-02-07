module apt_vault::utils {
    use std::string;
    use std::string::String;

    public fun prepend_utf8(str: String, bytes: vector<u8>): String {
        let new_str = string::utf8(bytes);
        string::append(&mut new_str, str);

        new_str
    }
}
