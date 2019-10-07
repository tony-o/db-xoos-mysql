use DB::Xoos:ver<0.1.0+>;
use DB::Xoos::Util::DSN;
use DB::Xoos::MySQL::Util::Dynamic;
use DB::Xoos::MySQL::Searchable;
unit class DB::Xoos::MySQL does DB::Xoos;

multi method connect(Any:D :$!db, :%options?) {
  my %dynamic;
  %dynamic = generate-structure(:db-conn($!db))
    if %options<dynamic>;
  self.load-models(%options<model-dirs>//[], :%dynamic);
  for self!get-cache-keys -> $key {
    my $model := self!get-cache($key);
    next if $model ~~ DB::Xoos::MySQL::Searchable;
    $model does DB::Xoos::MySQL::Searchable;
  }
}

multi method connect(Str:D $dsn, :%options?) {
  my %connect-params = parse-dsn($dsn);

  die 'Unable to parse DSN '~$dsn
    unless %connect-params.elems;

  my $db;
  my %db-opts = |(:%connect-params<db>//{ });
  %db-opts<database> = %connect-params<db>   if %connect-params<db>;
  %db-opts<host>     = %connect-params<host> if %connect-params<host>;
  %db-opts<port>     = %connect-params<port> if %connect-params<port>;
  %db-opts<user>     = %connect-params<user> if %connect-params<user>;
  %db-opts<password> = %connect-params<pass> if %connect-params<pass>;

  my $conninfo = join " ",
    ('dbname=' ~ %db-opts<database>),
    ('host=' ~ %db-opts<host>),
    ('user=' ~ %db-opts<user> if %db-opts<user>.defined),
    ('password=' ~ %db-opts<password> if %db-opts<password>.defined);

  $db = DB::MySQL.new(
    :database(%connect-params<db>),
    :host(%connect-params<host>),
    :port(%connect-params<port>),
    :user(%connect-params<user>),
    :password(%connect-params<pass>),
  );

  self.connect(
    :$db
    :%options,
  );
}
