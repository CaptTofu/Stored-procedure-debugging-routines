drop table if exists users;
create table users ( user_id int(11) not null auto_increment,
                     created timestamp,
                     username varchar(32) not null default '',
                     primary key (user_id),
                     index username (username)) engine = innodb;

drop table if exists randlog;
create table randlog (id int(11) not null auto_increment,
                      created timestamp,
                      username varchar(32) not null default '',
                      rvalue float,
                      returned smallint not null default 0,
                      primary key (id)) engine = innodb;


drop table if exists userloop_count;

create table userloop_count (id int(11) not null auto_increment,
                            created timestamp,
                            count int(11),
                            username varchar(32) not null default '',
                            primary key (id)) engine = innodb;
                            

