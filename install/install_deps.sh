echo Installing cassandra...
echo "deb http://debian.datastax.com/community stable main" | tee -a /etc/apt/sources.list.d/cassandra.sources.list
curl -L http://debian.datastax.com/debian/repo_key | apt-key add -

apt-get update
apt-get install dsc20=2.0.11-1 cassandra=2.0.11

echo Installing cpanminus...
apt-get install cpanminus

echo Installing Perl Cassandra libs...
apt-get install g++
cpanm perlcassa
cpanm Net::Async::CassandraCQL

echo Installing Mojolicious...
apt-get install curl
cpanm Mojolicious
cpanm Mojolicious::Plugin::Authentication

echo Installing Additional Perl Libs...
cpanm File::Slurp
cpanm JSON
cpanm LWP::Simple
cpanm Term::ReadKey
cpanm Moo
cpanm Crypt::PBKDF2
cpanm Text::Autoformat
cpanm Text::Format