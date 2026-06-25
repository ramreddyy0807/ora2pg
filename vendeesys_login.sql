-- =====================================================================
-- PostgreSQL equivalent of Oracle VENDEESYS.LOGIN procedure
-- Converted from Oracle PL/SQL to Azure PostgreSQL (PL/pgSQL)
--
-- Conversion notes:
--   - VARCHAR2                      → VARCHAR
--   - NUMBER                        → NUMERIC
--   - SYSTIMESTAMP                  → CURRENT_TIMESTAMP
--   - SYSDATE - changeDays          → CURRENT_DATE - changeDays
--                                     (PostgreSQL supports DATE - INTEGER)
--   - OUT parameter                 → INOUT with DEFAULT NULL
--   - %ROWTYPE                      → same syntax works in PostgreSQL
--   - Local var named 'record'      → renamed to 'rec'
--                                     ('record' is a type keyword in PL/pgSQL)
--   - EXCEPTION WHEN NO_DATA_FOUND  → same in PL/pgSQL
--
-- Result codes:
--   1 = 認証成功 (Authentication success)
--   2 = 暫定パスワード or パスワード期限切れでログイン成功
--   3 = ユーザーデータなし (No data found)
--   4 = パスワード認証失敗 (Password mismatch)
--   5 = パスワードを間違えてロックされた (Wrong password → now locked)
--   6 = ユーザーはロックされている (User is locked)
-- =====================================================================

CREATE OR REPLACE PROCEDURE vendeesys.login(
    IN    systemuserid  NUMERIC,
    IN    usercode      VARCHAR,
    IN    password      VARCHAR,
    IN    failurecount  NUMERIC,
    IN    changedays    NUMERIC,
    INOUT result        NUMERIC DEFAULT NULL
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
     WHERE system_user_id = systemuserid
       AND available = 1
     FOR UPDATE;

    -- ロックパターン: ユーザはロックされている
    IF rec.attention_failure_count >= failurecount THEN
        result := 6;

    -- 認証失敗パターン
    ELSIF password != rec.password THEN

        IF rec.attention_failure_count < (failurecount - 1) THEN
            -- ロックされていない状態でパスワードを間違えた
            result := 4;
        ELSIF rec.attention_failure_count = (failurecount - 1) THEN
            -- パスワードを間違えてロックされた
            result := 5;
        ELSIF rec.attention_failure_count >= failurecount THEN
            -- 暫定パスワードを間違えた
            result := 4;
        END IF;

        -- 認証失敗カウントを更新
        UPDATE password_management
           SET attention_failure_count = rec.attention_failure_count + 1,
               update_user             = usercode,
               update_date             = CURRENT_TIMESTAMP
         WHERE system_user_id = systemuserid;

    -- 認証成功パターン
    ELSIF password = rec.password THEN

        IF rec.attention_failure_count >= failurecount THEN
            -- 暫定パスワードでログイン成功
            result := 2;
        ELSIF rec.password_last_update_date < (CURRENT_DATE - changedays) THEN
            -- パスワードでログイン成功でライフ終了 (password expired)
            -- Oracle: SYSDATE - changeDays → CURRENT_DATE - changedays
            result := 2;
        ELSE
            -- 認証成功
            result := 1;
        END IF;

        -- 認証失敗カウントをクリア
        UPDATE password_management
           SET attention_failure_count = 0,
               update_user             = usercode,
               update_date             = CURRENT_TIMESTAMP
         WHERE system_user_id = systemuserid;

    END IF;

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        -- ユーザーデータなし
        result := 3;

END;
$$;


-- =====================================================================
-- Example: how to call the procedure
-- =====================================================================
-- DO $$
-- DECLARE
--     v_result NUMERIC;
-- BEGIN
--     CALL vendeesys.login(
--         systemuserid => 1,
--         usercode     => 'user001',
--         password     => 'hashed_password',
--         failurecount => 5,
--         changedays   => 90,
--         result       => v_result
--     );
--     RAISE NOTICE 'Login result: %', v_result;
--     -- 1 = success, 2 = expired/temp pw, 3 = not found, 4 = wrong pw, 5 = locked, 6 = already locked
-- END;
-- $$;
