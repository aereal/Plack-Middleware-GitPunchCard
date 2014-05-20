package Plack::Middleware::GitPunchCard;
use strict;
use warnings;
use parent qw( Plack::Middleware );
use Plack::Util::Accessor qw( path json_path max_log_count git_dir );
use JSON::XS qw( encode_json );
use List::UtilsBy qw( count_by );

sub prepare_app {
    my ($self) = @_;
    $self->json_path($self->path . '.json') unless defined $self->json_path;
    $self->git_dir('./.git') unless defined $self->git_dir;
}

sub call {
    my ($self, $env) = @_;
    if ($env->{PATH_INFO} eq $self->json_path) {
        my $series = $self->series_data($self->commit_datetime);
        my $body = encode_json($series);
        return [200, ['Content-Type' => 'application/json', 'Content-Length' => length($body)], [$body]];
    } elsif ($env->{PATH_INFO} eq $self->path) {
        my $body = $self->html;
        return [200, ['Content-Type' => 'text/html; charset=utf-8', 'Content-Length' => length($body)], [$body]];
    } else {
        return $self->app->($env);
    }
}

sub series_data {
    my ($self, $times) = @_;
    my %count_by_day = count_by { $self->_serialize_time($_)} @$times;
    [ map {
        my $t = $self->_deserialize_time($_);
        ['', 0+$t->{hour}, 1+$t->{weekday}, 0+$count_by_day{$_}, 0+$count_by_day{$_}]
    } keys %count_by_day ];
}

sub commit_datetime {
    my ($self) = @_;
    my $limit_opt = $self->git_log_limit_opt;
    my $out = `git --no-pager log --format='%at' --no-merges $limit_opt`;
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
    $t->{hour} . ':' . $_->{weekday}
}

sub _deserialize_time {
    (undef, my $key) = @_;
    my ($hour, $weekday) = split ':', $key;
    +{ hour => $hour, weekday => $weekday };
}

our $html = <<'EOF';
<!DOCTYPE html>
<html>
  <head>
    <meta charset="utf-8">
    <title>Git Punch Card</title>
    <script src="//www.google.com/jsapi"></script>
    <script src="//cdnjs.cloudflare.com/ajax/libs/jquery/2.1.1/jquery.js"></script>
    <script type="text/javascript">
    google.load('visualization', '1', { packages: ['corechart']});
    google.setOnLoadCallback(function () {
      $.getJSON(location.pathname + '.json', function (series) {
        var dataArray = [
            ['ID', 'Time', 'Weekday', '', 'commits'],
        ].concat(series);
        var data = google.visualization.arrayToDataTable(dataArray);

        var options = {
            hAxis: {
                title: 'Time',
                ticks: [0, 4, 7, 10, 13, 19, 22],
            },
            vAxis: {
                title: 'Weekday',
                maxValue: 8,
                minValue: 0,
                ticks: [
                    { v: 1, f: "Sun" },
                    { v: 2, f: "Mon" },
                    { v: 3, f: "Tue" },
                    { v: 4, f: "Wed" },
                    { v: 5, f: "Thu" },
                    { v: 6, f: "Fri" },
                    { v: 7, f: "Sat" },
                ],
            },
            'charArea.width' : window.screen.availWidth,
            'charArea.height' : window.screen.availHeight,
        };

        var chart = new google.visualization.BubbleChart(document.getElementById('chart'));
        chart.draw(data, options);
      });
    });
    </script>
    <style>
        html,body,#chart { height: 100%; }
    </style>
  </head>
  <body>
    <div id="chart"></div>
  </body>
</html>
EOF

sub html {
    $html;
}

1;
