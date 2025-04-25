pub const UniqueId = struct {
    mostSigBits: i64 = 0,
    leastSigBits: i64 = 0,

    pub fn getJavaSignature() [*c]const u8 {
        return "Ljava/util/UUID;";
    }
};
