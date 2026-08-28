function digest = CMCTextHash(value)
%CMCTEXTHASH Compute a stable SHA-256 digest for protocol metadata.

    value = char(string(value));
    engine = java.security.MessageDigest.getInstance('SHA-256');
    engine.update(uint8(unicode2native(value,'UTF-8')));
    bytes = typecast(engine.digest(),'uint8');
    digest = lower(string(reshape(dec2hex(bytes,2).',1,[])));
end
