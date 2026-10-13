-- ==============================================================================
-- ROW LEVEL SECURITY (RLS) POLICIES FOR SUPABASE
-- Kiến trúc tối ưu hóa: Sử dụng SECURITY DEFINER function để triệt tiêu
-- nguy cơ Infinite Recursion (vòng lặp đệ quy) giữa documents và document_permissions.
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1. KÍCH HOẠT ROW LEVEL SECURITY (RLS)
-- ------------------------------------------------------------------------------
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.document_permissions ENABLE ROW LEVEL SECURITY;

-- ------------------------------------------------------------------------------
-- 2. HELPER FUNCTIONS (SECURITY DEFINER - Chống vòng lặp đệ quy & Tăng tốc độ)
-- ------------------------------------------------------------------------------

-- Hàm kiểm tra user hiện tại có phải chủ sở hữu của tài liệu hay không
CREATE OR REPLACE FUNCTION public.is_document_owner(doc_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.documents
    WHERE id = doc_id AND owner_id = (auth.uid())::text
  );
$$;

-- Hàm kiểm tra user hiện tại có quyền edit đối với tài liệu hay không
CREATE OR REPLACE FUNCTION public.can_edit_document(doc_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.document_permissions
    WHERE document_id = doc_id 
      AND user_id = (auth.uid())::text 
      AND permission_level = 'edit'
  );
$$;

-- ------------------------------------------------------------------------------
-- 3. POLICIES CHO BẢNG `users`
-- ------------------------------------------------------------------------------
DROP POLICY IF EXISTS "Users can view profile" ON public.users;
CREATE POLICY "Users can view profile"
ON public.users
FOR SELECT
TO authenticated
USING (true);

DROP POLICY IF EXISTS "Users can update own profile" ON public.users;
CREATE POLICY "Users can update own profile"
ON public.users
FOR ALL
TO authenticated
USING (id = (auth.uid())::text)
WITH CHECK (id = (auth.uid())::text);

-- ------------------------------------------------------------------------------
-- 4. POLICIES CHO BẢNG `documents`
-- ------------------------------------------------------------------------------

-- SELECT: Chủ sở hữu HOẶC người được cấp quyền ('view' hoặc 'edit')
DROP POLICY IF EXISTS "Select documents policy" ON public.documents;
CREATE POLICY "Select documents policy"
ON public.documents
FOR SELECT
TO authenticated
USING (
    owner_id = (auth.uid())::text
    OR EXISTS (
        SELECT 1 FROM public.document_permissions
        WHERE document_permissions.document_id = documents.id
          AND document_permissions.user_id = (auth.uid())::text
          AND document_permissions.permission_level IN ('view', 'edit')
    )
);

-- INSERT: Chỉ cho phép authenticated user thêm tài liệu với owner_id chính là id của họ
DROP POLICY IF EXISTS "Insert documents policy" ON public.documents;
CREATE POLICY "Insert documents policy"
ON public.documents
FOR INSERT
TO authenticated
WITH CHECK (
    owner_id = (auth.uid())::text
);

-- UPDATE: Cho phép owner HOẶC user có quyền 'edit' trong document_permissions
DROP POLICY IF EXISTS "Update documents policy" ON public.documents;
CREATE POLICY "Update documents policy"
ON public.documents
FOR UPDATE
TO authenticated
USING (
    owner_id = (auth.uid())::text
    OR public.can_edit_document(documents.id)
)
WITH CHECK (
    owner_id = (auth.uid())::text
    OR public.can_edit_document(documents.id)
);

-- DELETE: Chỉ cho phép owner xóa tài liệu
DROP POLICY IF EXISTS "Delete documents policy" ON public.documents;
CREATE POLICY "Delete documents policy"
ON public.documents
FOR DELETE
TO authenticated
USING (
    owner_id = (auth.uid())::text
);

-- ------------------------------------------------------------------------------
-- 5. POLICIES CHO BẢNG `document_permissions`
-- ------------------------------------------------------------------------------

-- SELECT: Xem quyền nếu là Owner của tài liệu HOẶC chính người được cấp quyền
DROP POLICY IF EXISTS "Select permissions policy" ON public.document_permissions;
CREATE POLICY "Select permissions policy"
ON public.document_permissions
FOR SELECT
TO authenticated
USING (
    user_id = (auth.uid())::text
    OR public.is_document_owner(document_permissions.document_id)
);

-- INSERT: Chỉ owner của tài liệu mới có quyền gán quyền chia sẻ
DROP POLICY IF EXISTS "Insert permissions policy" ON public.document_permissions;
CREATE POLICY "Insert permissions policy"
ON public.document_permissions
FOR INSERT
TO authenticated
WITH CHECK (
    public.is_document_owner(document_permissions.document_id)
);

-- UPDATE: Chỉ owner của tài liệu mới có quyền thay đổi mức quyền
DROP POLICY IF EXISTS "Update permissions policy" ON public.document_permissions;
CREATE POLICY "Update permissions policy"
ON public.document_permissions
FOR UPDATE
TO authenticated
USING (
    public.is_document_owner(document_permissions.document_id)
)
WITH CHECK (
    public.is_document_owner(document_permissions.document_id)
);

-- DELETE: Chỉ owner của tài liệu mới có quyền thu hồi quyền chia sẻ
DROP POLICY IF EXISTS "Delete permissions policy" ON public.document_permissions;
CREATE POLICY "Delete permissions policy"
ON public.document_permissions
FOR DELETE
TO authenticated
USING (
    public.is_document_owner(document_permissions.document_id)
);
