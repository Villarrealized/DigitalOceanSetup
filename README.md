# Digital Ocean Production Setup
   * [Droplet Creation And Setup](#droplet-creation-and-setup)
      * [Creating Your Droplet](#creating-your-droplet)
      * [Logging In To Your Droplet](#logging-in-to-your-droplet)
      * [Installing Updates](#installing-updates)
   * [Production Server Setup](#production-server-setup)
      * [Installing Nginx Proxy And LetsEncrypt Auto SSL](#installing-nginx-proxy-and-letsencrypt-auto-ssl)
      * [Setting Up DNS](#setting-up-dns)
      * [Adding Applications](#adding-applications)
      * [Building And Compiling Vue Projects](#building-and-compiling-vue-projects)
      * [Applications With A MongoDB Database](#applications-with-a-mongodb-database)    
   * [Starting Application](#starting-application)
      * [Inspecting MongoDB Databases](#inspecting-mongodb-databases)
      * [Logging And Monitoring](#logging-and-monitoring)
      * [Local Development Setup](#local-development-setup)     
 
## **Droplet Creation And Setup**

### __Creating Your Droplet__
Select `Create > Droplets`. Choose `One-click apps > Docker`. Choose appropriate droplet size and data center. `San Francisco 2` is best because of proximity and the ability to create `Volumes` for your database. Check `Monitoring` and `Backups`. Make sure to select SSH keys for connecting to this droplet. Add a new one if necessary. Change the hostname to something more appropriate with a consistent naming convention. Ex. `company-0`, `company-1`. Click `Create`.

### __Logging In To Your Droplet__
You can now connect to your server via ssh.
```bash
# Pass in the IP your droplet was assigned and the private ssh key
# that corresponds to the public one you added during creation.
ssh root@93.184.216.34 -i ~/.ssh/id_rsa
```

To make it easier to connect to the server, add an entry to your `~/.ssh/config` file like so:

```bash
# Company 1 DigitalOcean Server
Host company-1 # The shortcut name you pass to ssh to login 
    HostName 93.184.216.34 # The IP assigned to your droplet
    User root # The user to log in as, should be root
    IdentityFile ~/.ssh/id_rsa # your private ssh key for connecting
```
Now logging in is painless:

```bash
# log in using your config host alias
ssh company-1
```

### __Installing Updates__
Before making any changes, it's a good idea to install the latest system updates for security and stability.

```bash
# Update and upgrade packages without user confirmation
apt update -y && apt upgrade -y
# Reboot to apply all changes
reboot
```

## **Production Server Setup**

### __Installing Nginx Proxy And LetsEncrypt Auto SSL__
You will need to create a few files to get your nginx reverse proxy server running so that you can serve multiple apps on the same server without port conflicts. You will also setup the LetsEncrypt creation and auto-renewal service for easy SSL.
```bash
# Make sure you are in the right directory
cd ~

# Let's store the docker-compose in its own directory
mkdir nginx-proxy-letsencrypt

# Navigate to the new directory
cd nginx-proxy-letsencrypt

# Download and create a docker-compose from this repository
curl https://raw.githubusercontent.com/Villarrealized/DigitalOceanSetup/master/docker-compose.prod.yml > docker-compose.yml

# Make a directory for nginx files
mkdir /etc/nginx

# Download and create the nginx template file needed
curl https://raw.githubusercontent.com/Villarrealized/DigitalOceanSetup/master/nginx.tmpl > /etc/nginx/nginx.tmpl
```

Now that everything is setup for your nginx reverse proxy server to run, you can boot it up.

```bash
# First, you need to add a docker network that all apps will share in common. You only need to do this once. nginx-proxy is the name of the network specified in the docker-compose.yml
docker network create nginx-proxy

# Bring up the server and run container in background
# Leave out -d to follow logs immediately. CTRL-Z to stop following logs without killing the container
docker-compose up -d

# Follow the logs - CTRL-C to stop following
docker-compose logs -f
```

### __Setting Up DNS__
First, make sure that the public url you want people to use to connect is pointing to this server by creating `A` records.

```DNS
A example.com 93.184.216.34
A www.example.com 93.184.216.34
```
That's all you have to do for DNS! Your nginx reverse proxy server will take care of the rest.

You can check on the status of your DNS changes like so:
```bash
# The address should be your server's ip
# Use -a flag for more info
host example.com
```

*Note:* If you would like all requests to example.com to be routed to www.example.com:

```bash
# Navigate to nginx virtual host directory
cd /etc/nginx/vhost.d

# Create redirect to www from non-www
echo "return 301 https://www.example.com$request_uri;" > example.com
```

### __Adding Applications__
Now that the nginx proxy server is up and running, you can add applications to be served up.

If your repo is private and you use ssh to connect, you will need to create an ssh key on this server and then upload the public key to BitBucket. 

```bash
# Generate SSH key on server
# Press Enter on all questions (leave as default)
ssh-keygen

# Output public key so you can copy and paste it to BitBucket
cat ~/.ssh/id_rsa.pub
```

Now navigate to the repo owner's Profile > Settings > SSH keys. Click `Add key` and enter a name that makes sense. Paste your key and click `Add key`.


If you are finished adding your public ssh key or the repo is not private, clone your repo:

```bash
# Return to home
cd ~

# Create a directory that all apps will live in
mkdir apps

# Navigate to new apps directory
cd apps

# Clone application repo
git clone git@bitbucket.org:your_username/your_app_repo.git my-awesome-app

#Navigate to new repo
cd my-awesome-app
```

At this point, you will need to add any environment variable files necessary that aren't included in the repo. If using docker-compose, it is recommended to specify a `env_file` option under your app's service with the path to the file, ex. `./.env` Minimum required environment variables are:
```bash
NODE_ENV=production
PORT=80
# The following two are required for nginx and letsencrypt to function properly. You can add multiple hosts via comma seperated list eg. host1.com,host2.com
VIRTUAL_HOST=your-app-url.example.com
LETSENCRYPT_HOST=your-app-url.example.com
```

### __Building And Compiling Vue Projects__
Before you can get a Vue.js app up and running you will need to build and compile it. To do this, you must install `node` and `npm`.

```bash
cd ~
# Install Node from a PPA to get newer version (replace 9.x with different version number if necessary)
curl -sL https://deb.nodesource.com/setup_9.x -o nodesource_setup.sh

# Run the setup script
bash nodesource_setup.sh

#Remove the setup script
rm nodesource_setup.sh

# The PPA has been added so now install nodejs (will automatically install npm too)
apt install nodejs

# Necessary for compiling npm packages from source
apt install build-essential
```

Now that node and npm are installed, install the npm packages in the client folder and build the production code.

```bash
# From the project root directory
cd client

# Install npm packages
npm install

# Back to root project dir
cd ..

# Run production build script
./build-productions.sh
```

### __Applications With A MongoDB Database__

If the app has a MongoDB database it is recommended to add a seperate env file for mongo, ex. `mongo.env` with the following values to enable authentication and security:
```bash
# The root username for authentication
MONGO_INITDB_ROOT_USERNAME=admin
# Password to use for MONGO_INITDB_ROOT_USERNAME
MONGO_INITDB_ROOT_PASSWORD=tAeKP6kN7cfryxfC
```

And then adjust your `MONGODB_URI` in your app's `.env` file like so : 
```bash
MONGODB_URI=mongodb://admin:tAeKP6kN7cfryxfC@db:27017/db-name?authSource=admin
```

You can easily generate a password for MongoDB with:
```bash
# Generate random 16 character string
# Add this command as an alias to your ~/.bash_profile, ~/.bashrc or ~/.bash_aliases for quick use
LC_ALL=C < /dev/urandom tr -dc A-Za-z0-9 | head -c16; echo
```

#### __Warnings And Optimizations__

To avoid warnings about [Transparent Huge Page](https://docs.mongodb.com/master/tutorial/transparent-huge-pages/) and to ensure better MongoDB performance:
```bash
# Install sysfsutils
apt install sysfsutils

# Set Huge Page Enabled to 'never' for best MongoDB Performance
echo "kernel/mm/transparent_hugepage/enabled = never" >> /etc/sysfs.conf

# Set Huge Page Defrag to 'never' for best MongoDB Performance
echo "kernel/mm/transparent_hugepage/defrag = never" >> /etc/sysfs.conf

# Restart the sysfsutils service to enable changes
systemctl restart sysfsutils.service
```


#### __Utilizing XFS To Avoid Performance Issues__
There is an additional warning about using the XFS filesystem instead of EXT4 on Linux for better performance. See [XFS vs EXT4 – Comparing MongoDB Performance on AWS EC2](https://scalegrid.io/blog/xfs-vs-ext4-comparing-mongodb-performance-on-aws-ec2/?utm_campaign=Blog%20-%20XFS%20vs%20EXT4%20-%20Comparing%20MongoDB%20Performance%20on%20AWS%20EC2&utm_source=Stack%20Overflow%20-%20XFS%20vs%20EXT4&utm_medium=Blog%20-%20XFS%20vs%20EXT4) and [MongoDB on Linux](https://docs.mongodb.com/manual/administration/production-notes/#mongodb-on-linux)

Switching to XFS is highly recommended, but isn't strictly necessary and may not produce a measurable improvement on a system with low demand, but with heavier workloads and a SSD, it should provide a significant performance increase.

To utilize XFS, add a 1GB Volume through the DigitalOcean control panel. The space can always be increased, but NEVER decreased. 1GB should be plenty for most databases. The initial size without any data is about 333M. 

If you are adding the volume after Droplet creation, do not follow the instructions provided for mounting and adding the drive. You will need to set it up slightly differently.

Once the volume has been created, enter the following code to create the XFS filesystem and mount it permanently.

```bash
# Find out what block devices you have
lsblk

# Create a new disk partition on the volume you added
# Replace 'sda' with the name of the block you want to format
# This will probably be sda if it is the first volume you have added
fdisk /dev/sda
# Enter 'n' for new partition
# Accept the defaults by pressing enter several times
# Enter 'w' to write and save changes or 'q' to quit without saving changes

# List the block devices. You should now see 'sda1' or similar under sda
lsblk

# Format the partition as XFS
mkfs.xfs /dev/sda1

# Create a local mount point for the drive
mkdir -p /mnt/my-awesome-app-db

# Mount the partition as XFS
mount -t xfs /dev/sda1 /mnt/my-awesome-app-db

# Verify that the XFS mount was succesful
df -Th /mnt/my-awesome-app-db

# Create a permanent mount point in fstab
echo "/dev/sda1    /mnt/my-awesome-app-db    xfs    defaults,nofail,discard    0 0 " >> /etc/fstab
```

Now the disk is mounted and should remount on every reboot. Make sure your application is pointed to the mount point `/mnt/my-awesome-app-db` for storing its database files

## **Starting Application**

Once you have added all the necessary environment variables for your app, double check everything and then you can run `docker-compose build && docker-compose up -d`. As long as the DNS is resolving to your server you should be seeing your application!

If you need to bring down the application for any reason, make sure you are in the right directory and then run `docker-compose down`

### __Inspecting MongoDB Databases__
If using a tool like Studio3T to inspect and view your MongoDB databases, you can connect to the databse by creating a new connection and selecting `SSH Tunnel`

`SSH Address`: Enter your server ip. Leave `Port` at `22` 

`SSH User name`: root

`SSH Auth Mode`: Private Key

`Private Key`: Specify path to your private key you use to connect to the server

Under `Authentication`,  make sure to enter the proper credentials as normal.

Test and save the connection.

### __Logging And Monitoring__
To view the nginx proxy server logs:
```bash
#Navigate to location of docker-compose
cd ~/nginx-proxy-letsencrypt

# Follow logs, leave off -f to simply see output
docker-compose logs -f
```

To view the logs for each application and db (if applicable)
```bash
# Navigate to app
cd ~/apps/my-awesome-app

# Follow logs
docker-compose logs -f
```

Alternatively, you can view the logs this way that includes some additional info:
```bash
# Find container id of container you want the logs for
docker ps

#print output of logs for container 6fae2e8c7898
cat $(docker inspect --format='{{.LogPath}}' 6fae2e8c7898)
```

To see a real-time log of containers and their resource usage, run `docker stats`.

To view total system memory usage and stats, run `free -hwt`

# __Local Development Setup__
   * [Installing Docker](#installing-docker)
   * [Installing Nginx Proxy](#installing-nginx-proxy)
   * [Preparing Your Application](#preparing-your-application)
     * [Docker Setup](#docker-setup)
     * [Adding Your Application URL to hosts file](#adding-your-application-url-to-hosts-file)
     * [Creating SSL Certs For Your Application](#creating-ssl-certs-for-your-application)
   * [Starting Nginx And Your Application](#starting-nginx-and-your-application)

## __Installing Docker__
You want to maintain a local development environment that mirrors your production environment as close as possible. To do this, you will install and use `Docker` for your development environment. Download and install [Docker Community Edition](https://store.docker.com/search?offering=community&type=edition) for your OS.

Once Docker is installed, and you have set any preferences concerning the CPU, RAM, Disk Usage, etc. you are ready to get started.

## __Installing Nginx Proxy__
Setting up an Nginx proxy server will help you in mirroring your production setup as well as making it easier to develop locally. First, you will create a new directory and download the files needed for the nginx proxy server.

```bash
# Create a new dir called 'nginx'
# You may create this dir whererver makes the most sense
# The example will create it in the home directory
cd ~

mkdir nginx

# Enter new dir
cd nginx

# Create a directory for nginx-proxy-template
mkdir docker-nginx-proxy

# Download docker-compose for development
curl https://raw.githubusercontent.com/Villarrealized/DigitalOceanSetup/master/docker-compose.dev.yml > docker-nginx-proxy/docker-compose.yml

# Download Nginx template file
curl https://raw.githubusercontent.com/Villarrealized/DigitalOceanSetup/master/nginx.tmpl > nginx.tmpl
```

## __Preparing Your Application__

Before you can run your application on the behind the nginx-proxy server, you will first need to setup a few different things in your application and on your local machine.

### __Docker Setup__
Make sure you have a `Dockerfile` and a `docker-compose.yml` in your application's code directory. Make sure The `Dockerfile` exposes port `80` and the `docker-compose` exposes port `80` also. Ensure that the application has an environment variable `VIRTUAL_HOST` that equals the url you would like to visit for the application. For example:
```bash
# In application .env file

# Whatever you put here is what Nginx will try to resolve for
VIRTUAL_HOST=my-awesome-app.dev.local

# Make sure your application is listening on port 80 for traffic
PORT=80
```

### __Adding Your Application URL to system hosts file__
Additionally, just as you made each domain's DNS A record point to the production server's IP, you will need to make sure that the dev url you are using resolves to your localhost. Modify `/etc/hosts` on Mac/Linux and `c:\WINDOWS\system32\drivers\etc\hosts` on Windows.
```bash
# In /etc/hosts
# Add an entry to 127.0.0.1 with your application(s) local url(s) you want
127.0.0.1       localhost my-awesome-app.dev.local my-other-awesome-app.dev.local
```
You can verify that this works by pinging the new address:
```bash
# Ping dev url to make sure it works
ping my-awesome-app.dev.local

# Sample output, if successful
PING my-awesome-app.dev.local (127.0.0.1): 56 data bytes
64 bytes from 127.0.0.1: icmp_seq=0 ttl=64 time=0.073 ms
64 bytes from 127.0.0.1: icmp_seq=1 ttl=64 time=0.116 ms
^C
```

### __Creating SSL Certs For Your Application__
At this point, you could simply `docker-compose up` for both your `nginx-proxy` and custom application and all should work fine. However, your production application has SSL enabled through LetsEncrypt, but your local environment does not. This can create issues when testing and since you want your development enviroment as close as possible to production, you should add some self-signed SSL certs for your app. This is a little bit more difficult than the nice container you used in production, but it's not too bad once you set it up.

First, you need to become your own certificate authority, so that you can issue certs for your local domains! 
```bash
# Change directory to where you created the 'nginx' folder from earlier
cd ~/nginx

# Create a directory to hold your certificates and certificate authority credentials
mkdir -p certs/LocalCertAuthority

# Enter new dir
cd certs/LocalCertAuthority

# Create a RSA-2048 key for generating the Root SSL certificate
# You will be prompted for a passphrase that you will need to enter
# Each time that you use this key to generate a certificate
openssl genrsa -des3 -out rootCA.key 2048

# Generate a Root SSL cert. Valid for 1000 days or however long you like...
# You will be prompted for other optional info. Enter or accept defaults.
openssl req -x509 -new -nodes -key rootCA.key -sha256 -days 1000 -out rootCA.pem
```

Before you can use the new Root SSl certificate to generate certificates for your local domains, you must have your computer trust the root certificate. For Mac, open `Keychain Access` > `File` > `Import Items` Select `rootCA.pem` that you just created. Double click the imported certificate and change `Trust` > `When using this certificate` to `Always Trust`. For Windows, use `start > run >  mmc` and follow the directions [here](http://www.databasemart.com/howto/SQLoverssl/How_To_Install_Trusted_Root_Certification_Authority_With_MMC.aspx). For Linux, copy `rootCA.pem` to `/usr/local/share/ca-certificates` and rename it to `rootCA.crt`. Then run `sudo update-ca-certificates` for the system to grab the new certificate.

Now create a new directory specific to your app's domain name. Alternatively, you can also create a wildcard certificate which will cover all subdomains of a domain. ex. a wildcard cert for `dev.local` will cover `my-awesome-app.dev.local`, `my-other-awesome-app.dev.local`, `totally-sweet-app.dev.local` , etc. Since this is the most efficient and not any harder to setup, that is what you will do here. 

```bash
# switch back to main nginx/certs directory
cd ..

# Create directory for dev.local wildcard domain certs and info
# The name of this directory doesn't matter
mkdir dev.local.wildcard

# Switch to this directory
cd dev.local.wildcard
```
Next, create an OpensSSL configuration file that is needed when creating the certificate

```bash
# I use nano, feel free to use whatever text editor you prefer
nano dev.local.csr.conf

# Enter the following in the above file
# The only thing that NEEDS to be changed is the CN field
# Change this to reflect the domain you want to create the cert for
# In this case you will use *.dev.local to create a cert for all subdomains of dev.local
[req]
default_bits = 2048
prompt = no
default_md = sha256
distinguished_name = dn

[dn]
C=US
ST=RandomState
L=RandomCity
O=RandomOrganization
OU=RandomOrganizationUnit
emailAddress=hello@example.com
CN = *.dev.local
```

Next, create a v3.ext file in order to create a X509 v3 certificate

```bash
# Create and edit a new file 'v3.ext'
nano v3.ext
# Contents of file
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
subjectAltName = @alt_names

[alt_names]
DNS.1 = dev.local
DNS.2 = *.dev.local
```
Now you will create a certificate key and certificate signing request for *.dev.local (or whatever domain you chose):
```bash
openssl req -new -sha256 -nodes -out dev.local.csr -newkey rsa:2048 -keyout dev.local.key -config dev.local.csr.conf 
```

Finally, you must request a certificate using your certificate signing request you just created. You need to issue this request to the Root SSL certificate you created earlier:

```bash
# Create certificate by making request to Root CA
openssl x509 -req -in dev.local.csr -CA ../LocalCertAuthority/rootCA.pem -CAkey ../LocalCertAuthority/rootCA.key -CAcreateserial -out dev.local.crt -days 500 -sha256 -extfile v3.ext
```

Verify that `dev.local.key` and `dev.local.crt` exist in your current directory with `ls`.

Now copy both the key and the crt to the `nginx/certs` directory. This is where nginx will look for certs to use for your applications and the names of the key and the crt must be patterned after your local domain. For a wildcard cert it must be named after the root domain.

```bash
# Copy the certs to the nginx/certs directory
# dev.local.crt might be dev.local.csr on linux
cp dev.local.key dev.local.crt ..
```

## __Starting Nginx And Your Application__

You are finally ready to bring up your local application with a custom domain name and a local, self-signed cert!

```bash
# Change directories to where you put the nginx-proxy
cd ~/nginx/docker-nginx-proxy

# Bring up the nginx proxy container and detach
docker-compose up -d

# Change your directory to your application where your docker-compose lives
cd ~/my-awesome-app

# Build and run your app and detach
docker-compose build && docker-compose up -d

# Verify everything is working okay (CTRL+C to exit logs)
docker compose logs -f
```

If all went well, you should now be able to visit your application in your browser ex. https://my-awesome-app.dev.local
