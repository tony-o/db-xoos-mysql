use DB::MySQL;
unit class DB::Xoos::Mysql;

method get-db(%params, :%options?) {
  die 'No connection parameters provided to DB::Xoos::MySQL'
    unless %params.elems;

  DB::MySQL.new(
    :database(%params<db>),
    :host(%params<host>),
    :port(%params<port>),
    :user(%params<user>),
    :password(%params<pass>),
  );
}
