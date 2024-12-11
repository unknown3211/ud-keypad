import React, { useState, useEffect } from "react";
import "./App.css";
import { debugData } from "../utils/debugData";
import { useNuiEvent } from "../hooks/useNuiEvent";
import { fetchNui } from "../utils/fetchNui";
import { FaBackspace } from "react-icons/fa";

debugData([
  {
    action: "setVisible",
    data: true,
  },
]);

const App: React.FC = () => {
  const [password, setPassword] = useState("");
  const [correctPassword, setCorrectPassword] = useState("");

  useNuiEvent("setVisible", (data: any) => {});

  useEffect(() => {
    const handleMessage = (event: any) => {
      if (event.data.action === 'SendPasswordData') {
        setCorrectPassword(event.data.data);
      }
    };

    window.addEventListener("message", handleMessage);
    return () => {
      window.removeEventListener("message", handleMessage);
    };
  }, []);

  const handleInputChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    setPassword(e.target.value);
  };

  const handleKeyPress = (e: React.KeyboardEvent) => {
    if (e.key === 'Enter') {
      if (password === correctPassword) {
        fetchNui('passwordsucessful');
        ResetUi();
      } else {
        fetchNui('passwordincorrect');
        ResetUi();
      }
    }
  };

  const handleButtonClick = (num: number) => {
    setPassword((prevPassword) => prevPassword + num.toString());
  };

  const handleBackspaceClick = () => {
    setPassword((prevPassword) => prevPassword.slice(0, -1));
  };

  const ResetUi = () => {
    setPassword('');
  }

  return (
    <div className="container flex justify-center items-center h-screen">
      <div className="container-header">
        <h1>Keypad</h1>
        <p>Enter the code to proceed</p>
        <p>Press ESC to close</p>
        <p>Press ENTER to Submit</p>
        <div className="divider-header">
          <div className="line-header" />
        </div>
        <div className="input-container">
          <input
            type="password"
            className="code-header outline-none bg-transparent"
            placeholder="Enter Code"
            value={password}
            onChange={handleInputChange}
            onKeyPress={handleKeyPress}
          />
        </div>
        <div className="flex flex-wrap justify-center gap-[10px]">
          {[1, 2, 3, 4, 5, 6, 7, 8, 9, 0].map((num) => (
            <button key={num} className="button-header" onClick={() => handleButtonClick(num)}>
              {num}
            </button>
          ))}
          <button className="button-header delete-header" onClick={handleBackspaceClick}><FaBackspace /></button>
        </div>
      </div>
    </div>
  );
};

export default App;