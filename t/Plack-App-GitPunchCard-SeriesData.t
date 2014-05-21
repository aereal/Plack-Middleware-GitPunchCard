use strict;
use warnings;
use HTTP::Request::Common qw( GET );
use JSON::XS;
use Plack::Test;
use Test::More;

require_ok 'Plack::App::GitPunchCard::SeriesData';

no warnings qw( redefine once );
local *Plack::App::GitPunchCard::SeriesData::commit_datetime = sub {
  [ +{ hour => 12, weekday => 1 } ];
};

subtest 'configure path' => sub {
  my $app = Plack::App::GitPunchCard::SeriesData->new;

  test_psgi $app, sub {
    my ($cb) = @_;

    my $res = $cb->(GET '/');
    is $res->code, 200;
    is $res->content_type, 'application/json';
    is_deeply JSON::XS::decode_json($res->content), [['', 12, 2, 1, 1]];
  };
};

done_testing;
