sudo apt-get install build-essential
sudo apt-get install libapache2-mod-proxy-html libxml2-dev
sudo apt-get install python-software-properties

a2enmod proxy
a2enmod proxy_http
a2enmod proxy_ajp
a2enmod rewrite
a2enmod deflate
a2enmod headers
a2enmod proxy_balancer
a2enmod proxy_connect
a2enmod proxy_html

sudo apt-get install openjdk-7-jre

wget -qO - https://packages.elasticsearch.org/GPG-KEY-elasticsearch | sudo apt-key add -
sudo add-apt-repository "deb http://packages.elasticsearch.org/elasticsearch/1.4/debian stable main"
echo may need to manually remove the src packages in sources list
sudo apt-get update && sudo apt-get install elasticsearch
sudo update-rc.d elasticsearch defaults 95 10

echo Installing cpanminus
apt-get install cpanminus

echo Installing Search::Elasticsearch
cpanm Search::Elasticsearch

echo Installing Mojolicious
apt-get install curl
cpanm Mojolicious
cpanm Mojolicious::Plugin::Authentication
cpanm Mojolicious::Plugin::REST

echo Installing Additional Perl Libs
cpanm File::Slurp
cpanm JSON
cpanm LWP::Simple
cpanm Term::ReadKey
cpanm Moo
cpanm Crypt::PBKDF2
cpanm Text::Autoformat
cpanm Text::Format
cpanm Graph::Simple
cpanm Algorithm::Combinatorics
cpanm Time::Piece
cpanm Cache::Memcached::Fast
echo Done

echo Installing Memcached
cpanm memcached
