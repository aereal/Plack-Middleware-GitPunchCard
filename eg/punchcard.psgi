use Plack::Builder;

builder {
  enable "Plack::Middleware::GitPunchCard",
    path => '/git-punch-card', max_log_count => 3000;

  sub { [200, [], ['']] };
};
