import { createClient } from "npm:@supabase/supabase-js@2";
Deno.serve(async (request) => {
  if (request.method !== "POST") return new Response("Method not allowed", {status:405});
  const url = Deno.env.get("SUPABASE_URL")!;
  const auth = createClient(url,Deno.env.get("SUPABASE_ANON_KEY")!,{auth:{persistSession:false}});
  const bearer = request.headers.get("Authorization") ?? "";
  if (!bearer.startsWith("Bearer ")) return Response.json({message:"Sign in first"},{status:401});
  const {data:{user},error} = await auth.auth.getUser(bearer.slice(7));
  if (error || !user) return Response.json({message:"Sign in first"},{status:401});
  // This key stays exclusively in the managed server environment.
  const admin = createClient(url,Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,{auth:{persistSession:false}});
  for (;;) {
    const {data:files,error:listError} = await admin.storage.from("starflight-saves").list(user.id,{limit:100});
    if (listError) return Response.json({message:"Could not finish save cleanup. Please retry."},{status:500});
    if (!files?.length) break;
    const {error:removeError} = await admin.storage.from("starflight-saves").remove(files.map(file=>`${user.id}/${file.name}`));
    if (removeError) return Response.json({message:"Could not finish save cleanup. Please retry."},{status:500});
  }
  const {error:deleteError} = await admin.auth.admin.deleteUser(user.id);
  if (deleteError) return Response.json({message:"Could not delete account. Please retry."},{status:500});
  return Response.json({deleted:true});
});
