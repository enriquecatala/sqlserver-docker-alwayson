

-- Put the certificate at the credential folder and make sure the name is correct when you specify these two variables at Dockerfile
--# Certificate previously generated
--ENV CERTFILE "certificate/dbm_certificate.cer"
--ENV CERTFILE_PWD "certificate/dbm_certificate.pvk"

-- Time to build the container 
-- docker build -t sql2017_alwayson_node .

-- Run the container
-- docker run -p 14333:1433 -it sql2017_alwayson_node


-- connect to the 127.0.0.1,14333 and create the following login with certificate to be able to create the AO without cluster
--
CREATE LOGIN dbm_login WITH PASSWORD = 'Pa$$w0rd';
CREATE USER dbm_user FOR LOGIN dbm_login;
GO
-- create certificate
--
CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'Pa$$w0rd';
GO

CREATE CERTIFICATE dbm_certificate   
    AUTHORIZATION dbm_user
    FROM FILE = '/usr/certificate/dbm_certificate.cer'
    WITH PRIVATE KEY (
    FILE = '/usr/certificate/dbm_certificate.pvk',
    DECRYPTION BY PASSWORD = 'Pa$$w0rd'
)
GO

-- GO TO PRIMARY REPLICA
--
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

-- REPEAT CREATE ENDPOINT ON SECONDARY NODE
--

-- That�s it. The following code should be executed against the node
--

-- NOW TIME TO CREATE AG
--
SELECT name AS instancename FROM sys.servers
GO


CREATE AVAILABILITY GROUP [ag1]
    WITH (CLUSTER_TYPE = NONE)
    FOR REPLICA ON
        N'88a5282d3b31' 
     WITH (
        ENDPOINT_URL = N'tcp://88a5282d3b31:5022',
        AVAILABILITY_MODE = ASYNCHRONOUS_COMMIT,
         SEEDING_MODE = AUTOMATIC,
         FAILOVER_MODE = MANUAL,
        SECONDARY_ROLE (ALLOW_CONNECTIONS = ALL)
         ),
        N'88963beb65b8' 
    WITH (
         ENDPOINT_URL = N'tcp://88963beb65b8:5022',
        AVAILABILITY_MODE = ASYNCHRONOUS_COMMIT,
        SEEDING_MODE = AUTOMATIC,
        FAILOVER_MODE = MANUAL,
        SECONDARY_ROLE (ALLOW_CONNECTIONS = ALL)
        )
GO

-- execute in secondary nodes
ALTER AVAILABILITY GROUP [ag1] JOIN WITH (CLUSTER_TYPE = NONE)
ALTER AVAILABILITY GROUP [ag1] GRANT CREATE ANY DATABASE
GO
--

ALTER AVAILABILITY GROUP [ag1] ADD DATABASE test
GO
