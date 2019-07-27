# MySQL

docker run -p 23306:3306 --name mysql -e MYSQL_ROOT_PASSWORD=root -d mysql:5.7

mysql -uroot -proot -P23306

If you would like to see a complete list of available options, just run:
docker run -it --rm mysql:5.7 --verbose --help


# MYSQL_ROOT_PASSWORD=root 

mysql_data_dir=$HOME/dkstore/mysql/mysql5.7-data
mkdir -p $mysql_data_dir
docker run -p 23306:3306 --name mysql \
           --restart=always \
           -v $mysql_data_dir:/var/lib/mysql \
           -e MYSQL_ALLOW_EMPTY_PASSWORD=yes \
           -d \
           mysql:5.7

docker run --name m1 -e MYSQL_ALLOW_EMPTY_PASSWORD=yes -d mysql:5.7

docker run --name m2 -d mysql:5.7


load sample data

https://dev.mysql.com/doc/index-other.html

https://github.com/datacharmer/test_db

https://dev.mysql.com/doc/employee/en/

