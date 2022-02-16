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
 Методы:
 #### $binder = Bind::Bind->new()
 Создает экземпляр объекта.
 
 Параметры:
- db_host => Адрес сервера БД, необязательный;
- db_port => Порт сервера БД, необязательный;
- db_user => Имя оператора БД, обязательный;
- db_name => Название базы данных, обязательный;
- db_pass => Пароль БД, обязательный;
- from => Начальный адрес пула доступных адресов, необязательный;
- qty => Размер пула доступных адресов, необязательный;
- lease_qty => Количество выдаваемых адресов, необязательный.
#### init()
Делает некоторые установки в существующем объекте. По умолчанию при вызове обнуляет список клиентов, получивших адреса.
- from => Начальный адрес пула доступных адресов;
- qty => Размер пула доступных адресов;
- keep_nodes => (1/0) Нужно ли обнулять список выданных комплектов адресов.
#### $node = $binder->lease( $clientName )
Создает объект **Node**, арендатора адресов. Необязательный параметр $clientName служит вспомогательным (чисто для человеков) идентификатором. 
### Объект Node
Методы:
#### lease
Вызывается без параметров. Назначает объекту уникальную группу адресов.
#### release
Вызывается без параметров. Обнуляет список арендованных адресов.
#### dump_address
Возвращает содержимое таблицы адресов как [{...},{...},{...}].
#### dump_nodes
Возвращает содержимое таблицы клиентов как [{...},{...},{...}].
#### Доступные информативные ключи:
- $node->{'id'} = Уникальный ID;
- $node->{'name'} = Заданный при инициализации атрибут (см. $clientName выше);
- $node->{'pool'} = Массив (комбинация) арендованных адресов;
- $node->{'tries'} = Количество неудачных попыток выбрать комбинацию адресов;
- $node->{'assigned'} = (1/0) Была ли получена требуемая комбинация;
- $node->{'time'} = Время присвоения комбинации адресов;
- $node->{'elapsed'} = Время, затраченное на подбор комбинации.

### Алгоритм
В таблице адресов дополнительно сохраняем количество использования каждого адреса. Это дает возможность отсортировать список по частоте использования. Из первых [5] будем формировать комплект кандидатов. 

Этот подход не даст возможности перепробовать все (253! / 248!) комбинации, но обеспечит равномерную нагрузку адресов.

Проверка уникальности комплекта выполняется методами работы с массивами Postgesql. Далее рассматриваем только те случаи, когда комплект адресов неуникален. Для подбора комбинации используем два метода: 
1. Выборочную замену одного из адресов комплекта;
2. Последовательную полную замену адресов.
#### Выборочная замена
Последовательно заменяем один адрес из списка кадидатов на адрес из списка "запасных" адресов. Имеем в виду, что в списке кандидатов у нас наименее часто использованные адреса, а список "запасных" адресов также отсортирован по частоте их использования. Это увеличивает вероятность получить уникальную комбинацию как можно быстрее. При неудачном применении первого метода, используем второй метод
#### Последовательная замена
Все адреса списка кандидатов по очереди заменяются на адреса из "запасного" списка. Приоритет наименее часто использованных адресов сохраняется.
### Результаты
При тестировании отмечено:
- При распределении 8 адресов по 64 объектам успешно назначены адреса 56 объектам за 1.66 сек. Каждый адрес использован 35 раз. Последний объект обрабатывался 0.05 сек.
- 253 адреса распределены между 2048 объектами за 674.65 сек. Частота использования адресов - 40-41. Для назначения комплекта адресов последнему, 2048-му объекту, потребовалось 0.80 сек.
