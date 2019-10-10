use lib 't/lib';
use DXPHelper;
use Test;
use DB::Xoos::MySQL::Row;

state $db;
try {
  CATCH { default {
    plan 1;
    ok True, 'Skipping tests, unable to connect to mysql';
    exit 0;
  } }
  $db = get-db(options => { :dynamic, model-dirs => [ 't/' ]});
  die 'no connection' unless $db.db.query('select 1;').array;
}

plan 1;

subtest {
  my Int $uid = 10000.rand.Int;
  my Int $gid = 10000.rand.Int;
  my $model = $db.model('Customers');
  my (@obj, $obj, $search, $scratch, $stay);

  $model.insert({ name => 'hello world' });
  $stay = $model.search({name => 'XYZ123'});
  ok $model.search({
    name => 'test',
  }).^name.split('+{')[0], 'Model::Customers';#DB::Xoos::MySQL::Searchable;
  $model.insert({
    name => "test$uid",
  });
  $obj = $model.search({ :name("test$uid") }).first;
  is $stay.count, 0, 'stay did not get modified';
  @obj = $model.all;
  ok @obj.elems > 0, 'insert went ok';
  ok @obj[0] ~~ DB::Xoos::MySQL::Row, 'object does DB::Xoos::MySQL::Row';
  ok @obj.grep({ .name eq "test$uid" }).elems == 1, 'found our test obj';
  is $obj.name, @obj.grep({ .name eq "test$uid" })[0].name, 'got the right name for direct search';

  $obj = $model.search({ name => { 'like' => "\%$uid\%", } }).all.first;
  is $obj.name, "test$uid", '%like% search OK';

  $obj = $model.search({ name => [ "test$uid" ], }).first;
  is $obj.name, "test$uid", 'in works okay';

  $gid++ if $gid == $uid;
  $model.insert({ name => "test$gid" });
  $search  = $model.search({ name => [ "test$uid", "test$gid" ] }, { order-by => 'name' });
  is $search.count, 2, 'got two elements for first/next';
  is $search.first.name, "test$uid", "first of first/next with order-by";
  is $search.count, 2, 'did not modify search filter';
  is $search.next.name, "test$gid", "next of first/next with order-by";
  is $search.count, 2, 'did not modify search filter';
  is $search.next, Nil, 'beyond end of cursor for search nets a Nil';

  is $search.update({ name => 'hello world' }), 2, '.update updated two rows and was really happy to tell us about it';

  $search = $model.search({ name => 'hello world' });
  $search.delete;
  is $search.all.elems, 0, '.all after .delete nets zero results';
  is $search.count, 0, '.count nets same result';

}, 'OK';
