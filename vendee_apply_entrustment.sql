-- =====================================================================
-- PostgreSQL equivalent of Oracle VENDEE.APPLY_ENTRUSTMENT procedure
-- Converted from Oracle PL/SQL to Azure PostgreSQL (PL/pgSQL)
--
-- Conversion notes:
--   - VARCHAR2          → VARCHAR
--   - NUMBER            → NUMERIC
--   - SYSTIMESTAMP      → CURRENT_TIMESTAMP
--   - IS ... BEGIN      → LANGUAGE plpgsql AS $$ DECLARE ... BEGIN ... $$
-- =====================================================================

CREATE OR REPLACE PROCEDURE vendee.apply_entrustment(
    IN i_parent_office_code           VARCHAR,   -- 集約先事業所コード
    IN i_parent_sum_up_management_id  NUMERIC,   -- 集約先締処理管理ID
    IN i_child_sum_up_management_id   NUMERIC    -- 集約元締処理管理ID
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_system_timestamp  TIMESTAMP;
BEGIN

    v_system_timestamp := CURRENT_TIMESTAMP;

    -- 集約元締処理管理の更新
    UPDATE sum_up_management
       SET entrust_customer_office_code = i_parent_office_code,
           update_user                  = 'BGJOB',
           update_date                  = v_system_timestamp
     WHERE id = i_child_sum_up_management_id;

    -- 締処理明細の登録
    UPDATE sum_up_detail
       SET sum_up_management_id = i_parent_sum_up_management_id,
           update_user          = 'BGJOB',
           update_date          = v_system_timestamp
     WHERE sum_up_management_id = i_child_sum_up_management_id;

END;
$$;


-- =====================================================================
-- Example: how to call the procedure
-- =====================================================================
-- CALL vendee.apply_entrustment(
--     i_parent_office_code           => 'OFFICE001',
--     i_parent_sum_up_management_id  => 1001,
--     i_child_sum_up_management_id   => 2001
-- );
