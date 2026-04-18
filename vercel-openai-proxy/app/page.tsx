export default function Home() {
  return (
    <main style={{ fontFamily: "system-ui", padding: 24 }}>
      <h1>OpenAI proxy API</h1>
      <p>
        POST to <code>/api/chat</code> with{" "}
        <code>Authorization: Bearer &lt;Firebase ID token&gt;</code> and JSON{" "}
        <code>{`{ "messages": [...] }`}</code>.
      </p>
    </main>
  );
}
