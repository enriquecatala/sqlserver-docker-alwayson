# sqlserver-docker-alwayson

Docker templates to create a SQL Server 2017 availability group solution with 3 nodes

## How to create an AlwaysOn topology with 3 nodes using docker

To deploy an AlwaysON topology from scratch, we have an [example image](##How_to_create_the_image_from_scratch) created to test the environment. You can create a complete environment by following the next steps:

1. Build the infrastructure (3 nodes named: sqlNode1, sqlNode2 and sqlNode3)

```cmd
docker-compose build
```

2. Run the infrastructure

```cmd
docker-compose up
```

_Now, you have a 3 node sharing the network and prepared to be part of a new availability group_

3. Connect to sqlNode1 (for example) and [create the availability group](###Create_availability_group)

_NOTE: You can [add manually more nodes](###Add_extra_nodes_to_the_availability_group) (up to 9)_

4. Connect to sqlNode2 and sqlNode3 and [join the node to the AG1](###Join_node_to_availability_group)

_Now, AlwaysOn AG1 **is up and running**, waiting for new databases to be part of it :)_

5. [Add databases to the availability group](###Add_databases_to_the_availability_group)

### Add databases to the availability group

If you have the alwayson configured, now you can add databases to the availability group by executing the following code:

```sql
ALTER AVAILABILITY GROUP [ag1] ADD DATABASE YourDatabase
GO
```

_NOTE: Database must exist at primary node and must have a full backup_

### Create availability group

To create the availability group with only one node, please connect to the instance that will be node 1 and execute the following code:

```sql
CREATE AVAILABILITY GROUP [AG1]
    WITH (CLUSTER_TYPE = NONE)
    FOR REPLICA ON
    N'sqlNode1'
        WITH (
        ENDPOINT_URL = N'tcp://sqlNode1:5022',
        AVAILABILITY_MODE = ASYNCHRONOUS_COMMIT,
            SEEDING_MODE = AUTOMATIC,
            FAILOVER_MODE = MANUAL,
        SECONDARY_ROLE (ALLOW_CONNECTIONS = ALL)
            ),
    N'sqlNode2'
        WITH (
        ENDPOINT_URL = N'tcp://sqlNode2:5022',
        AVAILABILITY_MODE = ASYNCHRONOUS_COMMIT,
            SEEDING_MODE = AUTOMATIC,
            FAILOVER_MODE = MANUAL,
        SECONDARY_ROLE (ALLOW_CONNECTIONS = ALL)
            ),
    N'sqlNode3'
        WITH (
        ENDPOINT_URL = N'tcp://sqlNode3:5022',
        AVAILABILITY_MODE = ASYNCHRONOUS_COMMIT,
            SEEDING_MODE = AUTOMATIC,
            FAILOVER_MODE = MANUAL,
        SECONDARY_ROLE (ALLOW_CONNECTIONS = ALL)
            )
```

### Add extra nodes to the availability group

More nodes (up to 9) can be added to this topology with the following code:

1. Execute the following code against the new node you want to add

```sql
DECLARE @servername AS sysname
SELECT @servername=CAST( SERVERPROPERTY('ServerName') AS sysname)

DECLARE @cmd AS VARCHAR(MAX)

SET @cmd ='
ALTER AVAILABILITY GROUP [AG1]    
    ADD REPLICA ON
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

-- NOW, go to primary replica and execute the output script generated
--
PRINT @create_ag
```

2. Copy the output script and execute it against the primary node of your topology

### Join node to availability group

The last part is to join each secondary node to the availability group by executing the following command:

```sql
ALTER AVAILABILITY GROUP [ag1] JOIN WITH (CLUSTER_TYPE = NONE)
ALTER AVAILABILITY GROUP [ag1] GRANT CREATE ANY DATABASE
GO
```
_execute against the secondary node you want to add_

## How to create the image from scratch

The image used at https://hub.docker.com/r/enriquecatala/sql2017_alwayson_node/ has been created by following the steps:

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

5. Stop the docker container

6. Search for the _CONTAINER ID_ that we want to create as a new image

```cmd
docker container list -a
```

7. Commit the container as a new image

```cmd
docker commit 17fed7500df3 sql2017_alwayson_node 
```

8. Search for the _IMAGE ID_ of the new image created in the previous step

```cmd
docker image list
```

9. Put a tag to the image

```cmd
docker tag 530873517958 enriquecatala/sql2017_alwayson_node:latest
```

10. Push to your repository

```cmd
docker push enriquecatala/sql2017_alwayson_node
```


### References

https://docs.microsoft.com/en-us/sql/linux/sql-server-linux-availability-group-cross-platform?view=sql-server-2017
