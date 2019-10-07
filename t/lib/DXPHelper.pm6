use DB::Xoos::MySQL;
unit module DXPHelper;

my $db;
sub get-db(*%_) is export {
  return $db if $db ~~ DB::Xoos::MySQL;
  my $dsn = %*ENV<XOOS_TEST> // 'mysql://xoos:@127.0.0.1/xoos';
  my $promise = Promise.new;
  await Promise.anyof(
    start { sleep 5; try $promise.break; },
    start {
      CATCH { .say; }
      $db = DB::Xoos::MySQL.new(:prefix(''));
      $db.connect($dsn, |%_);
      $db = Nil unless $db.db.query('select 1 as x;').hash<x> == 1;
      try $promise.keep;
    }
  );

  return $db if $promise.status ~~ Kept;
  warn ' DID NOT CONNECT ';
  Nil;
}

