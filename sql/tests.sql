create table customers (
  id serial not null primary key,
  name varchar(255)
);

create table orders (
  id serial not null primary key,
  customer integer not null,
  value float,
  foreign key(customer) references customers(id)
);
