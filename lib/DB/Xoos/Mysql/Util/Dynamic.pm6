use DB::Xoos::Util::DSN;
use DB::MySQL;
unit module DB::Xoos::MySQL::Util::Dynamic;

my %queries =
  list-tables    => "SELECT table_name FROM information_schema.tables WHERE table_schema=database() AND table_type='BASE TABLE';",
  list-columns   => "select is_nullable nullable, column_name as \"name\", data_type \"type\", case when extra = 'auto_increment' then true else false end auto_increment, character_maximum_length length from INFORMATION_SCHEMA.COLUMNS where table_name = ?",
  list-keys      => "SELECT c.column_name \"name\", c.data_type \"type\" FROM information_schema.table_constraints tc JOIN information_schema.key_column_usage AS ccu USING (constraint_schema, constraint_name) JOIN information_schema.columns AS c ON c.table_schema = tc.constraint_schema AND tc.table_name = c.table_name AND ccu.column_name = c.column_name WHERE constraint_type = 'PRIMARY KEY' and tc.table_name = ?",
  list-relations => 'SELECT `TABLE_NAME`, `COLUMN_NAME`, `REFERENCED_TABLE_NAME`, `REFERENCED_COLUMN_NAME` FROM `information_schema`.`KEY_COLUMN_USAGE` WHERE `CONSTRAINT_SCHEMA` = database() AND `REFERENCED_TABLE_SCHEMA` IS NOT NULL AND `REFERENCED_TABLE_NAME` IS NOT NULL AND `REFERENCED_COLUMN_NAME` IS NOT NULL ',
;

my %translate =
  'character varying' => 'varchar',
  'bigint'            => 'int',
;

sub column-sort {
  ($^a.value<is-primary-key>//False) && !($^b.value<is-primary-key>//False)
    ?? -1
    !! (!$^a.value<is-primary-key>//False) && ($^b.value<is-primary-key>//False)
      ?? 1
      !!  $^a.key cmp $^b.key
  ;
}

sub generate-structure (Str :$dsn?, :$db-conn?, Bool :$dry-run = False, :@tables? = []) is export {
  die "Please provide :dsn or :db-conn" unless $dsn.defined || $db-conn.defined;
  my $db = $db-conn;
  if !$db-conn.defined {
    my %parsed-dsn = parse-dsn($dsn);
    my $module     = "DB::Xoos::MySQL";

    CATCH { default { .say; } }
    $db = DB::MySQL.new(:%parsed-dsn);

  }
  CATCH { default { .say; } };
  my @define-tables = @tables.elems ?? @tables !! $db.db.query(%queries<list-tables>).arrays.map({ $_[0] });
  { note 'No tables were found in database'; exit 1; }()
    unless @define-tables.elems;

  my %files;

  # build relationship map
  my @relations = $db.query(%queries<list-relations>).hashes;
  my (%rel-table);
  for @relations -> $rel {
    %rel-table{$rel<TABLE_NAME>}.push: {
      c1_name => $rel<COLUMN_NAME>,
      c2_name => $rel<REFERENCED_COLUMN_NAME>,
      t1_name => $rel<TABLE_NAME>,
      t2_name => $rel<REFERENCED_TABLE_NAME>,
    };
    %rel-table{$rel<REFERENCED_TABLE_NAME>}.push: %rel-table{$rel<TABLE_NAME>}[*-1];
  }

  for @define-tables.map({ $_[0] }) -> $table {
    my @columns   = $db.query(%queries<list-columns>, $table).hashes;
    my @keys      = $db.query(%queries<list-keys>, $table).hashes;
    my @relations = |%rel-table{$table}//();

    my %col-data;
    my %relations;
    my $type;
    for @columns -> $col {
      $type = $col<type>.can('decode') ?? $col<type>.decode !! $col<type>;
      %col-data{$col<name>} = {
        type     => %translate{$type}//$type,
        nullable => $col<nullable> eq 'YES' ?? True !! False,
        ($col<auto_increment> ?? auto-increment => True !! ()),
        ($col<length>.defined ?? length => $col<length> !! ()),
      };
    }
    for @keys -> $key {
      %col-data{$key<name>}<is-primary-key> = True;
      %col-data{$key<name>}<nullable> = False;
    }
    for @relations -> $rel {
      my $key = $rel<t1_name> eq $table ?? '1' !! '2';
      my $oky = $key eq '1' ?? '2' !! '1';
      %relations{$rel{"t{$oky}_name"}} = %(
        ($key eq '2' ?? :has-many !! :has-one),
        model  => $rel{"t{$oky}_name"}.split('_').map({.tc}).join,
        relate => {
          $rel{"c{$key}_name"} => $rel{"c{$oky}_name"},
        },
      );
    }
    %files{$table.split('_').map({ .tc }).join} = {
      name      => $table.split('_').map({ .tc }).join,
      table     => $table,
      columns   => %col-data,
      relations => %relations,
    };
  }
  %files;
}
