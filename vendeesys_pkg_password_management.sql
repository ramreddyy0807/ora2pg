-- =====================================================================
-- PostgreSQL equivalent of Oracle VENDEESYS.PKG_PASSWORD_MANAGEMENT package
-- Converted from Oracle PL/SQL to Azure PostgreSQL (PL/pgSQL)
--
-- Conversion notes:
--   - PACKAGE / PACKAGE BODY         → individual procedures in vendeesys schema
--                                      named: pkg_password_management_<procedure>
--   - VARCHAR2                        → VARCHAR
--   - NUMBER                          → NUMERIC
--   - SYSTIMESTAMP                    → CURRENT_TIMESTAMP
--   - sequence.NEXTVAL FROM DUAL      → NEXTVAL('vendeesys.sequence_name')
--   - %ROWTYPE                        → same syntax works in PostgreSQL
--   - EXCEPTION WHEN NO_DATA_FOUND    → same in PL/pgSQL
--   - OUT parameters                  → INOUT with DEFAULT NULL
--   - Local var named 'record'        → renamed to 'rec' (reserved type in PL/pgSQL)
--   - Local var SYSTEM_TIMESTAMP      → renamed to v_system_timestamp (avoids collision)
-- =====================================================================


-- =====================================================================
-- 1. 登録 (regist)
-- =====================================================================
CREATE OR REPLACE PROCEDURE vendeesys.pkg_password_management_regist(
    IN    i_system_user_id           NUMERIC,
    IN    i_password                 VARCHAR,
    IN    i_attention_failure_count  NUMERIC,
    IN    i_create_user              VARCHAR,
    IN    i_remark                   VARCHAR,
    INOUT result                     NUMERIC DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_system_timestamp  TIMESTAMP;
    v_id                NUMERIC;
BEGIN

    -- システム時間
    v_system_timestamp := CURRENT_TIMESTAMP;

    -- ID採番
    SELECT NEXTVAL('vendeesys.password_management_seq') INTO v_id;

    INSERT INTO password_management (
        id,
        system_user_id,
        password,
        password1,
        password2,
        password3,
        password4,
        password5,
        attention_failure_count,
        password_last_update_date,
        available,
        create_date,
        create_user,
        update_date,
        update_user,
        remark
    ) VALUES (
        v_id,
        i_system_user_id,
        i_password,
        NULL,               -- password1
        NULL,               -- password2
        NULL,               -- password3
        NULL,               -- password4
        NULL,               -- password5
        i_attention_failure_count,
        v_system_timestamp, -- password_last_update_date
        1,                  -- available
        v_system_timestamp, -- create_date
        i_create_user,
        v_system_timestamp, -- update_date
        i_create_user,      -- update_user
        i_remark
    );

    -- 成功
    result := 1;

END;
$$;


-- =====================================================================
-- 2. 認証失敗回数の更新 (updateAttentionFailureCount)
-- =====================================================================
CREATE OR REPLACE PROCEDURE vendeesys.pkg_password_management_update_attention_failure_count(
    IN    i_system_user_id           NUMERIC,
    IN    i_attention_failure_count  NUMERIC,
    IN    i_update_user              VARCHAR,
    INOUT result                     NUMERIC DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_system_timestamp  TIMESTAMP;
BEGIN

    -- システム時間
    v_system_timestamp := CURRENT_TIMESTAMP;

    UPDATE password_management
       SET attention_failure_count = i_attention_failure_count,
           update_date             = v_system_timestamp,
           update_user             = i_update_user
     WHERE system_user_id = i_system_user_id;

    -- 成功
    result := 1;

END;
$$;


-- =====================================================================
-- 3. 論理削除 (deleteLogical)
-- =====================================================================
CREATE OR REPLACE PROCEDURE vendeesys.pkg_password_management_delete_logical(
    IN    i_system_user_id  NUMERIC,
    IN    i_update_user     VARCHAR,
    INOUT result            NUMERIC DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_system_timestamp  TIMESTAMP;
BEGIN

    -- システム時間
    v_system_timestamp := CURRENT_TIMESTAMP;

    UPDATE password_management
       SET available   = 0,
           update_date = v_system_timestamp,
           update_user = i_update_user
     WHERE system_user_id = i_system_user_id;

    -- 成功
    result := 1;

END;
$$;


-- =====================================================================
-- 4. システムユーザーIDによる検索 (findBySystemUserId)
-- =====================================================================
CREATE OR REPLACE PROCEDURE vendeesys.pkg_password_management_find_by_system_user_id(
    IN    i_system_user_id             NUMERIC,
    INOUT result                       NUMERIC    DEFAULT NULL,
    INOUT o_id                         NUMERIC    DEFAULT NULL,
    INOUT o_system_user_id             NUMERIC    DEFAULT NULL,
    INOUT o_password                   VARCHAR    DEFAULT NULL,
    INOUT o_password1                  VARCHAR    DEFAULT NULL,
    INOUT o_password2                  VARCHAR    DEFAULT NULL,
    INOUT o_password3                  VARCHAR    DEFAULT NULL,
    INOUT o_password4                  VARCHAR    DEFAULT NULL,
    INOUT o_password5                  VARCHAR    DEFAULT NULL,
    INOUT o_attention_failure_count    NUMERIC    DEFAULT NULL,
    INOUT o_password_last_update_date  TIMESTAMP  DEFAULT NULL,
    INOUT o_available                  NUMERIC    DEFAULT NULL,
    INOUT o_create_date                TIMESTAMP  DEFAULT NULL,
    INOUT o_create_user                VARCHAR    DEFAULT NULL,
    INOUT o_update_date                TIMESTAMP  DEFAULT NULL,
    INOUT o_update_user                VARCHAR    DEFAULT NULL,
    INOUT o_remark                     VARCHAR    DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
DECLARE
    -- Oracle: record PASSWORD_MANAGEMENT%ROWTYPE
    -- Renamed 'record' → 'rec' as 'record' is a type keyword in PL/pgSQL
    rec password_management%ROWTYPE;
BEGIN

    -- パスワード管理を検索して行ロック
    SELECT * INTO rec
      FROM password_management
     WHERE system_user_id = i_system_user_id
       AND available = 1
     FOR UPDATE;

    -- パスワード管理情報を取得
    o_id                        := rec.id;
    o_system_user_id            := rec.system_user_id;
    o_password                  := rec.password;
    o_password1                 := rec.password1;
    o_password2                 := rec.password2;
    o_password3                 := rec.password3;
    o_password4                 := rec.password4;
    o_password5                 := rec.password5;
    o_attention_failure_count   := rec.attention_failure_count;
    o_password_last_update_date := rec.password_last_update_date;
    o_available                 := rec.available;
    o_create_date               := rec.create_date;
    o_create_user               := rec.create_user;
    o_update_date               := rec.update_date;
    o_update_user               := rec.update_user;
    o_remark                    := rec.remark;

    -- 成功
    result := 1;

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        -- データなし
        result := 3;

END;
$$;


-- =====================================================================
-- Example: how to call each procedure
-- =====================================================================

-- 1. regist
-- DO $$
-- DECLARE v_result NUMERIC;
-- BEGIN
--     CALL vendeesys.pkg_password_management_regist(
--         i_system_user_id          => 1,
--         i_password                => 'hashed_password',
--         i_attention_failure_count => 0,
--         i_create_user             => 'admin',
--         i_remark                  => NULL,
--         result                    => v_result
--     );
--     RAISE NOTICE 'result: %', v_result;
-- END; $$;

-- 2. updateAttentionFailureCount
-- DO $$
-- DECLARE v_result NUMERIC;
-- BEGIN
--     CALL vendeesys.pkg_password_management_update_attention_failure_count(
--         i_system_user_id          => 1,
--         i_attention_failure_count => 3,
--         i_update_user             => 'admin',
--         result                    => v_result
--     );
--     RAISE NOTICE 'result: %', v_result;
-- END; $$;

-- 3. deleteLogical
-- DO $$
-- DECLARE v_result NUMERIC;
-- BEGIN
--     CALL vendeesys.pkg_password_management_delete_logical(
--         i_system_user_id => 1,
--         i_update_user    => 'admin',
--         result           => v_result
--     );
--     RAISE NOTICE 'result: %', v_result;
-- END; $$;

-- 4. findBySystemUserId
-- DO $$
-- DECLARE
--     v_result    NUMERIC;
--     v_id        NUMERIC;
--     v_password  VARCHAR;
-- BEGIN
--     CALL vendeesys.pkg_password_management_find_by_system_user_id(
--         i_system_user_id => 1,
--         result           => v_result,
--         o_id             => v_id,
--         o_password       => v_password
--         -- remaining INOUT params omitted for brevity; pass NULL for each
--     );
--     RAISE NOTICE 'result: %, id: %, password: %', v_result, v_id, v_password;
-- END; $$;
