package Plack::App::GitPunchCard::SeriesData;
use strict;
use warnings;
use parent qw( Plack::Component );
use JSON::XS;
use List::UtilsBy;
use Plack::Util::Accessor qw( max_log_count git_dir );

sub call {
  my ($self, $env) = @_;
  my $series = $self->series_data($self->commit_datetime);
  my $body = JSON::XS::encode_json($series);
  return [200, ['Content-Type' => 'application/json', 'Content-Length' => length($body)], [$body]];
}

sub series_data {
  my ($self, $times) = @_;
  my %count_by_day = List::UtilsBy::count_by { $self->_serialize_time($_)} @$times;
  [ map {
    my $t = $self->_deserialize_time($_);
    ['', 0+$t->{hour}, 1+$t->{weekday}, 0+$count_by_day{$_}, 0+$count_by_day{$_}]
  } keys %count_by_day ];
}

sub commit_datetime {
  my ($self) = @_;
  my $limit_opt = $self->git_log_limit_opt;
  my $git_dir = $self->git_dir;
  my $out = `git --git-dir $git_dir --no-pager log --format='%at' --no-merges $limit_opt`;
  my @lines = split "\n", $out;
  [ map { $self->_build_time_from_epoch($_) } @lines ];
}

sub git_log_limit_opt {
  my ($self) = @_;
  defined($self->max_log_count) ? '-n ' . $self->max_log_count : '';
}

sub _build_time_from_epoch {
  (undef, my $epoch) = @_;
  my ($hour, $weekday) = (localtime($epoch))[2, 6];
  +{ hour => $hour, weekday => $weekday };
}

sub _serialize_time {
  (undef, my $t) = @_;
  $t->{hour} . ':' . $t->{weekday}
}

sub _deserialize_time {
  (undef, my $key) = @_;
  my ($hour, $weekday) = split ':', $key;
  +{ hour => $hour, weekday => $weekday };
}

1;
