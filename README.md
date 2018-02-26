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
 
## **Droplet Creation And Setup**

### __Creating Your Droplet__
Select `Create > Droplets`. Choose `One-click apps > Docker`. Choose appropriate droplet size and data center. `San Francisco 1 & 2` is best because of proximity. Check `Monitoring` and `Backups`. Make sure to select SSH keys for connecting to this droplet. Add a new one if necessary. Change the hostname to something more appropriate with a consistent naming convention. Ex. `company-0`, `company-1`. Click `Create`.

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
# log in using our config host alias
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
curl https://raw.githubusercontent.com/Villarrealized/DigitalOceanSetup/master/nginx-proxy-lets-encrypt-docker-compose.yml > docker-compose.yml

# Make a directory for nginx files
mkdir /etc/nginx

# Download and create the nginx template file needed
curl https://raw.githubusercontent.com/Villarrealized/DigitalOceanSetup/master/nginx.tmpl > /etc/nginx/nginx.tmpl
```

Now that everything is setup for our nginx reverse proxy server to run, you can boot it up.

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
# Find out what block devices we have
lsblk

# Create a new disk partition on the volume you added
# Replace 'sda' with the name of the block you want to format
# This will probably be sda if it is the first volume you have added
fdisk /dev/sda
#Enter n for new partition
#Command (m for help): n
#Accept the defaults by pressing enter several times
#Enter 'w' to write and save changes or 'q' to quit without saving changes

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
