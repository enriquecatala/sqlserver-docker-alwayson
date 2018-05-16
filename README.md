# sqlserver-docker-alwayson
Docker templates to create a SQL Server 2017 availability group solution

## How to deploy an Availability Group with _n_ nodes with Docker and compose





## How to create the image from scratch

1. Connect to any SQL Server 2017 and execute this to create the certificate with private key

```sql
USE master
GO
CREATE LOGIN dbm_login WITH PASSWORD = 'Pa$$w0rd';
CREATE USER dbm_user FOR LOGIN dbm_login;
GO
-- create certificate
--
CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'Pa$$w0rd';
go
CREATE CERTIFICATE dbm_certificate WITH SUBJECT = 'dbm';
BACKUP CERTIFICATE dbm_certificate
TO FILE = 'd:\borrame\dbm_certificate.cer'
WITH PRIVATE KEY (
        FILE = 'd:\borrame\dbm_certificate.pvk',
        ENCRYPTION BY PASSWORD = 'Pa$$w0rd'
    );
GO
```

_This will be used to create a sql login maped to the certificate and replicated to the secondary nodes, required to create the AG_

2. Build the image

```cmd
docker build -t sql2017_alwayson_node .
```

3. Run the container

```cmd
docker run -p 14333:1433 -it sql2017_alwayson_node
```

4. Connect to the 127.0.0.1,14333 and create the following login with certificate to be able to create the AO without cluster

```sql
CREATE LOGIN dbm_login WITH PASSWORD = 'Pa$$w0rd';
CREATE USER dbm_user FOR LOGIN dbm_login;
GO
-- create master key encryption required to securely store the certificate
--
CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'Pa$$w0rd';
GO
-- import certificate with authorization to dbm_user
CREATE CERTIFICATE dbm_certificate   
    AUTHORIZATION dbm_user
    FROM FILE = '/usr/certificate/dbm_certificate.cer'
    WITH PRIVATE KEY (
    FILE = '/usr/certificate/dbm_certificate.pvk',
    DECRYPTION BY PASSWORD = 'Pa$$w0rd'
)
GO
-- Create the endpoint
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
```

5. Create the availability group with only one node

```sql
DECLARE @servername AS sysname
SELECT @servername=name FROM sys.servers

DECLARE @cmd AS VARCHAR(MAX)

SET @cmd ='
CREATE AVAILABILITY GROUP [AG1]
    WITH (CLUSTER_TYPE = NONE)
    FOR REPLICA ON
        N''<SQLInstanceName>''
     WITH (
        ENDPOINT_URL = N''tcp://<SQLInstanceName>:5022'',
        AVAILABILITY_MODE = ASYNCHRONOUS_COMMIT,
         SEEDING_MODE = AUTOMATIC,
         FAILOVER_MODE = MANUAL,
        SECONDARY_ROLE (ALLOW_CONNECTIONS = ALL)
         )
';

DECLARE @create_ag AS VARCHAR(MAX)
SELECT @create_ag = REPLACE(@cmd,'<SQLInstanceName>',@servername)

PRINT @create_ag

-- Finally, create the Availability group, but with only one node
EXEC(@create_ag)
```

6. Stop the docker container

7. Search for the _CONTAINER ID_ that we want to create as a new image

```cmd
docker container list -a
```

8. Commit the container as a new image

```cmd
docker commit 17fed7500df3 sql2017_alwayson_node 
```

9. Search for the _IMAGE ID_ of the new image created in the previous step

```cmd
docker image list
```

10. Put a tag to the image

```cmd
docker tag 530873517958 enriquecatala/sql2017_alwayson_node:latest
```

11. Push to your repository

```cmd
docker push enriquecatala/sql2017_alwayson_node
```

### References

https://docs.microsoft.com/en-us/sql/linux/sql-server-linux-availability-group-cross-platform?view=sql-server-2017
