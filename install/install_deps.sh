wget -qO - https://packages.elasticsearch.org/GPG-KEY-elasticsearch | sudo apt-key add -
sudo add-apt-repository "deb http://packages.elasticsearch.org/elasticsearch/1.4/debian stable main"
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
echo Done