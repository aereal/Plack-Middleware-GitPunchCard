use strict;
use warnings;
use HTTP::Request::Common qw( GET );
use JSON::XS;
use Plack::Builder;
use Plack::Test;
use Test::More;

require_ok 'Plack::Middleware::GitPunchCard';

no warnings qw( redefine once );
local *Plack::App::GitPunchCard::SeriesData::commit_datetime = sub {
  [ +{ hour => 12, weekday => 1 } ];
};

my $app = builder {
  enable 'Plack::Middleware::GitPunchCard', path => '/git-punch-card', json_path => '/series.json';
  sub { [200, ['Content-Type' => 'text/plain'], ['test']] };
};

test_psgi $app, sub {
  my ($cb) = @_;

  subtest 'root' => sub {
    my $res = $cb->(GET '/');
    is $res->code, 200;
    is $res->content_type, 'text/plain';
    is $res->content, 'test';
  };

  subtest 'Punch Card' => sub {
    my $res = $cb->(GET '/git-punch-card');
    is $res->code, 200;
    like $res->content, qr/Git Punch Card/;
  };

  subtest 'Punch Card JSON' => sub {
    my $res = $cb->(GET '/series.json');
    is $res->code, 200;
    is $res->content_type, 'application/json';
    is_deeply JSON::XS::decode_json($res->content), [['', 12, 2, 1, 1]];
  };
};

done_testing;
