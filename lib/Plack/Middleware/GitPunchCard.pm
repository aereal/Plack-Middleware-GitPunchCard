package Plack::Middleware::GitPunchCard;
use strict;
use warnings;
use parent qw( Plack::Middleware );
use Plack::App::GitPunchCard::SeriesData;
use Plack::Util::Accessor qw( path json_path max_log_count git_dir );
use Plack::Util;

sub prepare_app {
    my ($self) = @_;
    $self->{punchcard_html} //= $self->html;
    $self->{series_data} //= Plack::App::GitPunchCard::SeriesData->new(
      max_log_count => $self->max_log_count,
      git_dir => $self->git_dir // './.git',
    );
}

sub html {
  my ($self) = @_;
  local $/;
  my $html = <DATA>;
  my $sym = 'json_path';
  my $v = Plack::Util::encode_html($self->json_path);
  $html =~ s/\{\{\s*$sym\s*\}\}/$v/;
  $html;
}

sub call {
    my ($self, $env) = @_;
    my $path = $env->{PATH_INFO};
    if ($path eq $self->json_path) {
        return $self->{series_data}->call($env);
    } elsif ($path eq $self->path) {
        return [200, ['Content-Type' => 'text/html; charset=utf-8', 'Content-Length' => length($self->{punchcard_html})], [$self->{punchcard_html}]];
    } else {
        return $self->app->($env);
    }
}

1;

__DATA__
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
      $.getJSON($(document.body).attr('data-json-path'), function (series) {
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
  <body data-json-path="{{ json_path }}">
    <div id="chart"></div>
  </body>
</html>
