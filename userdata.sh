#!/bin/bash -xve


function handle_gunicorn()
{
# temp WA 
gunicorn --bind 0.0.0.0:8000 multiapp.wsgi --daemon
# aws s3 cp s3://$S3_ARTIFACT_BUCKET/gunicorn.service .
# sudo cp -f ./gunicorn.service /etc/systemd/system/
sudo cp -f $APP_DIR/dev_ops/configuration/gunicorn.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable gunicorn
sudo systemctl start gunicorn
sudo systemctl status gunicorn
}

function handle_nginx()
{
# aws s3 cp s3://$S3_ARTIFACT_BUCKET/nginx.conf .
# sudo cp -f ./nginx.conf /etc/nginx/
sudo cp -f $APP_DIR/dev_ops/configuration/nginx.conf /etc/nginx/
sudo systemctl restart nginx
sudo nginx -t
}

function handle_crontab()
{
sudo sh -c 'echo -e "\n*/5 * * * * cd /app/homelend && /usr/local/bin/python3.9 manage.py process_tasks --duration 295 --log-std" >> /var/spool/cron/root'
}


function handle_django()
{
python3.9 manage.py migrate users2
python3.9 manage.py migrate dbHL
python3.9 manage.py migrate

## Should be run only once
## add check before
# python3.9 manage.py shell -c "from scripts.python import set_ups; set_ups.init_prod()"

# WA fix for user already exist if running again
# psql --host prod1-rds-pg.cpomnimiekkm.us-east-1.rds.amazonaws.com  --port 5432 --user postgres  --dbname postgresql
# DROP DATABASE postgres WITH (FORCE);
# CREATE DATABASE postgres;
# run 13-15
## 
echo yes|python3.9 manage.py collectstatic
}

function handle_frontend()
{

sudo npm install
set +e
sudo npm audit fix
set -e
sudo npm run build
}

function setup_app()
{
cd $APP_DIR
pip3.9 install -r requirements.txt
# cd $APP_DIR/vue_frontend/
# handle_frontend
# cd $APP_DIR
handle_django
}


function run_app()
{
handle_gunicorn
handle_nginx
handle_crontab
echo ------ App successfully installed and ready to use! ----------------
}

function pull_artifacts_from_s3()
{
cd $APP_DIR
APP_TAR_FILE=$APP_VERSION.tar.gz 
aws s3 cp s3://$S3_ARTIFACT_BUCKET/$APP_TAR_FILE  $APP_DIR
tar zxvf $APP_TAR_FILE --strip-components=1
sudo rm -rf $APP_TAR_FILE.tar.gz 
chown -R ec2-user:ec2-user /app/homelend/
}

function pull_artifacts_from_git()
{
sudo mkdir -p $APP_DIR
cd $APP_DIR
sudo git init
sudo git remote add origin https://gitlab.com/HagaiGil/dj7
sudo git fetch --all
sudo git checkout master
}

function install_nginx()
{
sudo amazon-linux-extras enable nginx1
sudo yum install -y nginx
}

function install_os-packages()
{
sudo yum groupinstall "Development Tools" -y
sudo yum install openssl-devel libffi-devel xz-devel bzip2-devel -y
sudo yum install curl -y
sudo  yum install jq -y 
sudo yum install htop -y
}

function install_python()
{
wget https://www.python.org/ftp/python/3.9.5/Python-3.9.5.tgz
tar xvf Python-3.9.5.tgz
cd Python-3.9*/
./configure --enable-optimizations
sudo make altinstall
python3.9 --version
pip3.9 --version
}
function install_node()
{
curl -sL https://rpm.nodesource.com/setup_14.x | sudo bash -
sudo yum install -y nodejs
sudo npm install -g npm@latest
node -v
npm -v
}


function install_memcached()
{
sudo yum install memcached -y
sudo cp -f $APP_DIR/dev_ops/configuration/memcached /etc/sysconfig/memcached
sudo service memcached restart
}
function update_os()
{
 sudo yum update -y
 sudo yum upgrade -y
}

function install_httpd()
{
    sudo yum install httpd -y
    sudo systemctl start httpd 
    echo -e  "Hello my application\n"  | sudo tee -a /var/www/html/index.html
    echo -e  "Application version:$APP_VERSION\n"  | sudo tee -a /var/www/html/index.html
    echo -e  "$(hostname)\n"  | sudo tee -a /var/www/html/index.html
    echo -e  "$(date)\n"  | sudo tee -a /var/www/html/index.html
   # cat $ENV_FILE | sudo tee -a /var/www/html/index.html
}

function install_postgres_client()
{
   sudo amazon-linux-extras install postgresql13 -y
}

function define_fs()
{
    DEVICE=$1
    MOUNT_POINT=$2

    echo "Starting to create $MOUNT_POINT using $DEVICE "
    DEVICE_FS_TYPE=`file -sL $DEVICE `

    if [[ $DEVICE_FS_TYPE == *"ext4"* ]]; then
      echo "Device already formatted"
    else
      echo "Formatting $DEVICE with an Ext4 fs"
      sudo mkfs.ext4 -q -F $DEVICE
    fi

    #Label the device
    echo "Labelling $DEVICE"
    sudo e2label  $DEVICE $MOUNT_POINT

    #Backup fstab
    echo "Copying /etc/fstab to /etc/fstab.orig"
    sudo cp /etc/fstab /etc/fstab.orig

    if [ ! -d "$MOUNT_POINT" ]; then mkdir -p $MOUNT_POINT; fi

    #Add new entry to fstab for the new device
    echo "Adding new fstab entry"
    echo "LABEL=$MOUNT_POINT     $MOUNT_POINT           ext4    defaults,nofail  2   2" | sudo tee -a /etc/fstab

    #Mount all devices
    echo "Mounting all devices"
    sudo mount -a
    ls -l $MOUNT_POINT
    sudo chown ec2-user:ec2-user /app
    echo "$MOUNT_POINT created successfully "
 
}

function define_fs_once()
{
# define the application FS
# for more details see  https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ebs-using-volumes.html
if [ ! -d "$APP_DIR" ]
then
 define_fs /dev/nvme1n1 /app
 sudo mkdir -p $APP_DIR
 sudo chown -R ec2-user:ec2-user $APP_DIR
else
 echo "dir $APP_DIR exist"
fi
}

function  add_secrets()
{
 SECRET_NAME=$1
 echo "Adding $SECRET_NAME to $ENV_FILE "
 export SECRET_MAP=$(aws secretsmanager get-secret-value --secret-id "$SECRET_NAME"  --query SecretString --output text --region "$REGION")
 if [ "$SECRET_MAP" = "" ]
 then
	 echo "can find static secret $AWS_STATIC_SECRET_NAME"
	 exit 1
 fi
 echo -e "\n#added from AWS secret $SECRET_NAME "  >> $ENV_FILE
 echo  $SECRET_MAP |  jq -r "to_entries|map(\"\(.key)=\(.value|tostring)\")|.[]" >> $ENV_FILE
}

function add_static_parameters()
{
 STATIC_PARAMETERS_FILE=env_static_parameters.properties
 echo "Adding static parameters from $STATIC_PARAMETERS_FILE to $ENV_FILE"
 aws s3 cp s3://$S3_ARTIFACT_BUCKET/$STATIC_PARAMETERS_FILE .
 echo -e "\n#from $STATIC_PARAMETERS_FILE in $S3_ARTIFACT_BUCKET bucket" >> $ENV_FILE
 cat $STATIC_PARAMETERS_FILE >> $ENV_FILE
}

function add_dynamic_parameters()
{
 echo "Adding dynamic parameters to $ENV_FILE"  
 echo -e "\n\n#S3 app bucket"   >> $ENV_FILE
 echo "AWS_STORAGE_BUCKET_NAME=$ENV_S3_BUCKET" >> $ENV_FILE
}

function create_env_file()
{
 # TODO add to packages function
 sudo  yum install jq -y 
 if [ -f $ENV_FILE ]
 then
  echo "$ENV_FILE already exist .deleting file ... "
  rm -f $ENV_FILE
 fi  
 touch $ENV_FILE

 # example - external systems secrets
 add_secrets $AWS_STATIC_SECRET_NAME

 # example - external systems parameters
 add_secrets $AWS_STATIC_PARAMETER_NAME
 # example - RDS secrets 
 add_secrets $AWS_RDS_SECRET_NAME 

#  # example - env installation parameters
#  add_static_parameters

 # example s3 bucket name
 add_dynamic_parameters


}
#################### Starting main ######################## 
# Log all commands to /tmp/cloud-init.out
exec 1>/tmp/cloud-init.out 2>&1
DATE=`date`
echo "user data started :$DATE "  
export APP_VERSION_FROM_TERRAFORM="${app_version_tf}"
export ENV_NAME_FROM_TERRAFORM="${environment_name}"
export APP_S3_BUCKET_FROM_TERRAFORM="${s3_env_app_bucket}"

export S3_ARTIFACT_BUCKET="artifact-bucket-"$(aws sts get-caller-identity  --query Account --output text)
export REGION=`curl http://169.254.169.254/latest/dynamic/instance-identity/document|grep region|awk -F\" '{print $4}'`

export ROOT_APP=/app
export APP_DIR=$ROOT_APP/myapp
export ENV_FILE=$APP_DIR/envfile

export APP_VERSION=$APP_VERSION_FROM_TERRAFORM
export ENVIRONMENT_NAME=$ENV_NAME_FROM_TERRAFORM
export AWS_STATIC_SECRET_NAME=$ENVIRONMENT_NAME-static-secrets
export AWS_STATIC_PARAMETER_NAME=$ENVIRONMENT_NAME-static-parameters
export AWS_RDS_SECRET_NAME=$ENVIRONMENT_NAME-rds-secrets

export ENV_S3_BUCKET=$(echo $APP_S3_BUCKET_FROM_TERRAFORM |  awk -F: '{print $NF}')


define_fs_once

install_postgres_client
install_os-packages

pull_artifacts_from_s3

create_env_file

install_nginx
install_python
# install_node
install_memcached
# pull_artifacts_from_git

update_os

setup_app
run_app