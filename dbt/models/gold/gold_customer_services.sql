{{ config(materialized='view') }}

select customer_id, atributo, valor
from (
    select
        customer_id,
        cast(phone_service as string) as phone_service,
        cast(multiple_lines as string) as multiple_lines,
        cast(internet_service as string) as internet_service,
        cast(online_security as string) as online_security,
        cast(online_backup as string) as online_backup,
        cast(device_protection_plan as string) as device_protection_plan,
        cast(premium_support as string) as premium_support,
        cast(streaming_tv as string) as streaming_tv,
        cast(streaming_movies as string) as streaming_movies,
        cast(streaming_music as string) as streaming_music,
        cast(unlimited_data as string) as unlimited_data,
        cast(paperless_billing as string) as paperless_billing
    from {{ ref('gold_customer_data') }}
) as base
unpivot (
    valor for atributo in (
        phone_service, multiple_lines, internet_service, online_security,
        online_backup, device_protection_plan, premium_support,
        streaming_tv, streaming_movies, streaming_music,
        unlimited_data, paperless_billing
    )
)
order by customer_id, atributo
