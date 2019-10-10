create table customers (
  id integer not null primary key auto_increment,
  name varchar(255)
);

create table orders (
  id integer not null primary key auto_increment,
  customer integer not null,
  value float,
  foreign key(customer) references customers(id)
);
