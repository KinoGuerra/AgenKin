-- PostgreSQL exige confirmar el nuevo valor del enum antes de utilizarlo.
-- La migración siguiente instala la regla y actualiza los registros históricos.
alter type public.estado_vencimiento add value if not exists 'vencido';
