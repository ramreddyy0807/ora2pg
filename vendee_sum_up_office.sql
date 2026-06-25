-- =====================================================================
-- PostgreSQL equivalent of Oracle VENDEE.SUM_UP_OFFICE procedure
-- Converted from Oracle PL/SQL to Azure PostgreSQL (PL/pgSQL)
--
-- Conversion notes:
--   - VARCHAR2                          → VARCHAR
--   - NUMBER                            → NUMERIC
--   - SYSTIMESTAMP                      → CURRENT_TIMESTAMP
--   - sequence.NEXTVAL FROM DUAL        → NEXTVAL('schema.sequence_name')
--   - NEXTVAL in INSERT..SELECT         → NEXTVAL('schema.seq') inline in SELECT
--   - OUT parameter                     → INOUT parameter
--   - IS ... BEGIN                      → LANGUAGE plpgsql AS $$ DECLARE ... BEGIN ... $$
--   - DATE + 1 (add 1 day)              → same syntax works in PostgreSQL
-- =====================================================================

CREATE OR REPLACE PROCEDURE vendee.sum_up_office(
    IN    i_customer_code          VARCHAR,    -- 取引先コード
    IN    i_office_code            VARCHAR,    -- 事業所コード
    IN    i_sum_up_date            DATE,       -- 締日
    IN    i_sum_up_execute_date    TIMESTAMP,  -- 締処理実行日
    IN    i_sum_up_execute_person  VARCHAR,    -- 締処理実行者(自動実行の場合はNULL)
    INOUT o_sum_up_management_id   NUMERIC DEFAULT NULL  -- 処理結果
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_system_timestamp  TIMESTAMP;
    sumgmt_id           NUMERIC;
BEGIN

    -- システム時間と締処理管理IDの採番
    v_system_timestamp := CURRENT_TIMESTAMP;

    SELECT NEXTVAL('vendee.sum_up_management_seq') INTO sumgmt_id;

    -- OUTパラメータに値を設定
    o_sum_up_management_id := sumgmt_id;

    -- 締処理情報管理を登録する
    INSERT INTO sum_up_management (
        id,
        customer_code,
        customer_office_code,
        sum_up_date,
        sum_up_execute_date,
        sum_up_execute_person,
        cancel_date,
        cancel_person,
        is_cancel,
        entrust_customer_office_code,
        available,
        create_date,
        create_user,
        update_date,
        update_user,
        remark
    ) VALUES (
        sumgmt_id,
        i_customer_code,
        i_office_code,
        i_sum_up_date,
        i_sum_up_execute_date,
        i_sum_up_execute_person,
        NULL,                -- cancel_date
        NULL,                -- cancel_person
        0,                   -- is_cancel
        NULL,                -- entrust_customer_office_code
        1,                   -- available
        v_system_timestamp,  -- create_date
        'BGJOB',             -- create_user
        v_system_timestamp,  -- update_date
        'BGJOB',             -- update_user
        NULL                 -- remark
    );

    -- 締処理明細の登録
    -- Oracle: SUM_UP_DETAIL_SEQ.NEXTVAL in SELECT → NEXTVAL('vendee.sum_up_detail_seq') inline
    INSERT INTO sum_up_detail
    SELECT
        NEXTVAL('vendee.sum_up_detail_seq'),  -- id
        sumgmt_id,                            -- sum_up_management_id
        s.id,                                 -- sales_id
        1,                                    -- available
        v_system_timestamp,                   -- create_date
        'BGJOB',                              -- create_user
        v_system_timestamp,                   -- update_date
        'BGJOB',                              -- update_user
        NULL                                  -- remark
    FROM sales s
    INNER JOIN m_rw r
           ON s.rw_communication_number = r.rw_communication_number
    INNER JOIN m_vending_machine v
           ON r.vending_machine_id = v.id
    INNER JOIN m_customer_office c
           ON v.customer_office_id = c.id
    WHERE c.customer_code        = i_customer_code
      AND c.customer_office_code = i_office_code
      AND s.sum_up_select_sales_date < i_sum_up_date + 1
      AND s.is_sum_up_executed = 0
      AND s.available = 1
      AND r.available = 1
      AND v.available = 1
      AND c.available = 1;

    -- 販売管理テーブルの更新
    UPDATE sales s
       SET is_sum_up_executed = 1,
           update_user        = 'BGJOB',
           update_date        = v_system_timestamp
     WHERE EXISTS (
        SELECT 1
          FROM sum_up_detail sud
         WHERE sud.sales_id             = s.id
           AND sud.sum_up_management_id = sumgmt_id
     );

END;
$$;


-- =====================================================================
-- Example: how to call the procedure
-- =====================================================================
-- DO $$
-- DECLARE
--     v_out_id NUMERIC;
-- BEGIN
--     CALL vendee.sum_up_office(
--         i_customer_code         => 'CUST001',
--         i_office_code           => 'OFF001',
--         i_sum_up_date           => '2024-11-25',
--         i_sum_up_execute_date   => CURRENT_TIMESTAMP,
--         i_sum_up_execute_person => 'user01',
--         o_sum_up_management_id  => v_out_id
--     );
--     RAISE NOTICE 'SUM_UP_MANAGEMENT_ID: %', v_out_id;
-- END;
-- $$;
