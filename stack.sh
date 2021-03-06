#!/bin/bash
DATE=$(date +%F)
USER_ID=$(id -u)
LOG=/tmp/stack.log
TOMCAT_URL=http://mirrors.estointernet.in/apache/tomcat/tomcat-9/v9.0.19/bin/apache-tomcat-9.0.19.tar.gz
TOMCAT_FILE=$(echo $TOMCAT_URL | cut -d "/" -f9) #echo $TOMCAT_URL | awk -F "/" '{print $NF}'
TOMCAT_FOLDER=$(echo $TOMCAT_FILE | sed -e 's/.tar.gz//')
STUDENT_URL=https://github.com/devops2k18/DevOpsSeptember/raw/master/APPSTACK/student.war
MYSQL_URL=https://github.com/devops2k18/DevOpsSeptember/raw/master/APPSTACK/mysql-connector-java-5.1.40.jar
MYSQL_JAR=$(echo $MYSQL_URL | awk -F "/" '{print $NF}')

MODJK_URL=http://mirrors.estointernet.in/apache/tomcat/tomcat-connectors/jk/tomcat-connectors-1.2.46-src.tar.gz
MODJK_FILE=$(echo $MODJK_URL | awk -F "/" '{print $NF}')
MODJK_FOLDER=$(echo $MODJK_FILE | sed -e 's/.tar.gz//')

R="\e[31m"
G="\e[32m"
N="\e[0m"
Y="\e[33m"

VALIDATE(){
	if [ $1 -ne 0 ]; then
		echo -e "$2 ...$R FAILURE $N"
		exit 1
	else
		echo -e "$2 ... $G SUCCESS $N"
	fi
}

SKIP(){
	echo -e "$1...$Y SKIPPING $N"
}

echo "started scrit execution on $DATE"

yum install httpd -y  &>> $LOG

VALIDATE $? "Installing Apache"

systemctl start httpd  &>> $LOG

VALIDATE $? "Starting httpd"

systemctl enable httpd  &>> $LOG

VALIDATE $? "Enabling httpd"

#application server installations
yum install java -y &>> $LOG

VALIDATE $? "Installing Java"

cd /root/tomcat

if [ -f $TOMCAT_FILE ]; then
		SKIP "TOMCAT download"
else
	wget $TOMCAT_URL &>> $LOG
	VALIDATE $? "Downloading tomcat"
fi

if [ -d $TOMCAT_FOLDER ]; then
	SKIP "Extracting tomcat"
else
	tar -xf $TOMCAT_FILE
	VALIDATE $? "Extracting tomcat"
fi

cd apache-tomcat-9.0.19/webapps

wget $STUDENT_URL &>> $LOG

VALIDATE $? "Downloading student.war"

cd ../lib

if [ -f $MYSQL_JAR ]; then
	SKIP "Downloading MYSQL JAR"
else
	wget $MYSQL_URL &>> $LOG
	VALIDATE $? "Downloading MYSQL JAR"
fi

cd ../conf

sed -i -e '/TestDB/ d' context.xml

sed -i -e '$ i <Resource name="jdbc/TestDB" auth="Container" type="javax.sql.DataSource" maxTotal="100" maxIdle="30" maxWaitMillis="10000" username="student" password="student@1" driverClassName="com.mysql.jdbc.Driver" url="jdbc:mysql://10.142.0.22:3306/studentapp"/>' context.xml

VALIDATE $? "Editing context.xml"

cd ../bin

sh shutdown.sh &>>$LOG && sh startup.sh &>>$LOG

VALIDATE $? "restarting tomcat"

cd /root

if [ -f $MODJK_FILE ]; then
	SKIP "Downloading MOD_JK"
else
	wget $MODJK_URL &>> $LOG
	VALIDATE $? "Downloading MODJK"
fi

if [ -d $MODJK_FOLDER ]; then
	SKIP "Extracting MODJK"
else
	tar -xf $MODJK_FILE
	VALIDATE $? "Extracting MODJK"
fi

cd $MODJK_FOLDER/native

yum install gcc httpd-devel -y &>>$LOG

VALIDATE $? "Installing gcc apxs"

if [ -f /etc/httpd/modules/mod_jk.so ]; then
	SKIP "Compiling MODJK"
else
	./configure --with-apxs=/bin/apxs &>>$LOG && make &>>$LOG && make install &>>$LOG 
	VALIDATE $? "Compiling MODJK"
fi

cd /etc/httpd/conf.d

if [ -f modjk.conf ]; then
	SKIP "creating modjk.conf"
else
echo 'LoadModule jk_module modules/mod_jk.so
JkWorkersFile conf.d/workers.properties
JkLogFile logs/mod_jk.log
JkLogLevel info
JkLogStampFormat "[%a %b %d %H:%M:%S %Y]"
JkOptions +ForwardKeySize +ForwardURICompat -ForwardDirectories
JkRequestLogFormat "%w %V %T"
JkMount /student tomcatA
JkMount /student/* tomcatA' > modjk.conf

VALIDATE $? "creating modjk.conf"

fi

if [ -f workers.properties ]; then
	SKIP "creating workers.properties"
else
echo '### Define workers
worker.list=tomcatA
### Set properties
worker.tomcatA.type=ajp13
worker.tomcatA.host=localhost
worker.tomcatA.port=8009' > workers.properties
VALIDATE $? "Creating workers.properties"
fi

systemctl restart httpd


