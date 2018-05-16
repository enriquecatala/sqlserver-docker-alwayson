-- This script was executed before creating the docker image
-- So you can rely on these logins and objects
--


CREATE LOGIN dbm_login WITH PASSWORD = 'Pa$$w0rd';
CREATE USER dbm_user FOR LOGIN dbm_login;
GO
-- create certificate
--
CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'Pa$$w0rd';
go
CREATE CERTIFICATE dbm_certificate   
    AUTHORIZATION dbm_user
    FROM FILE = '/usr/certificate/dbm_certificate.cer'
    WITH PRIVATE KEY (
    FILE = '/usr/certificate/dbm_certificate.pvk',
    DECRYPTION BY PASSWORD = 'Pa$$w0rd'
)
GO

CREATE ENDPOINT [Hadr_endpoint]
    AS TCP (LISTENER_IP = (0.0.0.0), LISTENER_PORT = 5022)
    FOR DATA_MIRRORING (
        ROLE = ALL,
        AUTHENTICATION = CERTIFICATE dbm_certificate,
        ENCRYPTION = REQUIRED ALGORITHM AES
        );
ALTER ENDPOINT [Hadr_endpoint] STATE = STARTED;
GRANT CONNECT ON ENDPOINT::[Hadr_endpoint] TO [dbm_login]
GO

