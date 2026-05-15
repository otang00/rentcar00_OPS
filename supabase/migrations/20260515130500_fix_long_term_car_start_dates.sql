-- Fix manually confirmed long-term vehicle start dates that had month/day only.

update public.rc00_ops_cars
set start_at_ts = timestamp with time zone '2021-11-25 00:00:00+09'
where car_number = '29하2763';

update public.rc00_ops_cars
set start_at_ts = timestamp with time zone '2018-06-12 00:00:00+09'
where car_number = '34호7488';

update public.rc00_ops_cars
set start_at_ts = timestamp with time zone '2017-10-18 00:00:00+09'
where car_number = '34호7499';
