```bash
docker run \
  -p 8300:8300 \
  -p 8301:8301 \
  -p 8302:8302 \
  -p 8500:8500 \
  -p 8600:8600 \
  -p 4646:4646 \
  -p 4647:4647 \
  -p 4648:4648 \
  -p 9200:9200 \
  -p 5601:5601 \
  -p 5000:5000 \
  -v "/var/run/docker.sock:/var/run/docker.sock" \
  -v "/tmp:/tmp" \
  --name=devmasjien \
  --privileged \
  dev-container
```
```bash
docker run -p 8300:8300 -p 8301:8301 -p 8302:8302 -p 8500:8500 -p 8600:8600 -p 4646:4646 -p 4647:4647 -p 4648:4648 -p 9200:9200 -p 5601:5601 -p 5000:5000 -v "/var/run/docker.sock:/var/run/docker.sock" -v "/tmp:/tmp" --name=devmasjien --privileged dev-container
```

## Enable TCP/IP connectionstrings on SQLServer/SQLExpress

*  SQL Server Configuration Manager
  * Run SQLServerManager13.msc
* Go to SQL Server Network Configuration/Protocols for SQLExpress
  * Enable TCP/IP
  * Rightclick TCP/IP
    * If the value of Listen All is yes, the TCP/IP port number for this instance of SQL Server is the value of the TCP Dynamic Ports item under IPAll.
    * If the value of Listen All is no, the TCP/IP port number for this instance of SQL Server is the value of the TCP Dynamic Ports item for a specific IP address.
  * Make sure the TCP Port is 1433.
* Restart SQL Server

## Enable sa user and set password if needed