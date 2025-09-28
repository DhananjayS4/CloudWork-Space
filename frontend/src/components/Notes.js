import { useState, useEffect } from "react";
import axios from "axios";

function Notes() {
  const [notes, setNotes] = useState([]);
  const [text, setText] = useState("");

  const fetchNotes = async () => {
    const res = await axios.get("http://localhost:5000/api/notes");
    setNotes(res.data);
  };

  const addNote = async () => {
    await axios.post("http://localhost:5000/api/notes", { text });
    setText("");
    fetchNotes();
  };

  useEffect(() => { fetchNotes(); }, []);

  return (
    <div>
      <h2>Notes</h2>
      <textarea value={text} onChange={(e) => setText(e.target.value)} />
      <button onClick={addNote}>Add Note</button>
      <ul>
        {notes.map((n) => <li key={n._id}>{n.text}</li>)}
      </ul>
    </div>
  );
}
export default Notes;
