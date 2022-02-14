# mhTask
>Есть пул из 253 ip-адресов. Из пула выделяются комбинации по 5 ip-адресов и закрепляются за некоторым объектом. Каждый адрес может быть привязан более чем к одному объекту, но комбинация адресов каждого объекта должна быть уникальной, без учета порядка. Адреса, объекты и связи хранятся в БД. Нужно с минимальным расходом машинных ресурсов найти незанятую комбинацию ip-адресов с учетом того, что "используемость" адресов пула должна быть равномерной (т.е. избегать ситуации, когда несколько адресов связаны с существенно большим числом объектов, чем остальные). Для работы с БД использовать DBIx::Class, база PostgreSQL.
### Файлы
**binder.pl** - скрипт для демонстрации работы с объектом Bind. В скрипте указываются параметры соединения с сервером БД. Допускается удаленное соединение.

**binder.sql** - директивы для создания рабочих таблиц. Использование: 

    psql -d dbname -f binder.sql
    
 **Bind/Bind.pm** - Собственно, наш модуль, который все делает
 
 **Bind/Schema.pm** - Создается модулем DBIx::Class
 
    dbicdump -o dump_directory=./ Bind::Schema 'dbi:Pg:dbname=test;host=localhost;port=5432' userName userPass
 ### Bind::Bind
 Поддерживаемые методы:
 #### $binder = Bind::Bind->new()
 Создает экземпляр объекта.
 
 Параметры:
- db_host => Адрес сервера БД, необязательный
- db_port => Порт сервера БД, необязательный
- db_user => Имя оператора БД, обязательный
- db_name => Название базы данных, обязательный
- db_pass => Пароль БД, обязательный
- from => Начальный адрес пула доступных адресов, необязательный
- qty => Размер пула доступных адресов, необязательный
- lease_qty => Количество выдаваемых адресов, необязательный
#### init()
Делает некоторые установки в существующем объекте. По умолчанию при вызове обнуляет список клиентов, получивших адреса
- from => Начальный адрес пула доступных адоресов
- qty => Размер пула доступных адресов
- keep_nodes => (1/0) Нужно ли обнулять список выданных комплектов адресов
#### $node = $binder->lease( $clientName )
Создает объект **Node**, арендатора адресов. Необязательный параметр $clientName служит вспомогательным (чисто для человеков) идентификатором 
