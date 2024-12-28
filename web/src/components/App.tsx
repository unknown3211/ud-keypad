import React, { useState, useEffect } from "react";
import "./App.css";
import { debugData } from "../utils/debugData";
import { useNuiEvent } from "../hooks/useNuiEvent";
import { fetchNui } from "../utils/fetchNui";
import { FaBackspace } from "react-icons/fa";

debugData([
  {
    action: "setVisible",
    data: { visible: true, isChangingPassword: false },
  },
]);

const App: React.FC = () => {
  const [password, setPassword] = useState("");
  const [correctPassword, setCorrectPassword] = useState("");
  const [isChangingPassword, setIsChangingPassword] = useState(false);
  const [visible, setVisible] = useState(false);

  useNuiEvent("setVisible", (data: any) => {
    setVisible(data.visible);
    setIsChangingPassword(data.isChangingPassword);
  });

  useNuiEvent("setPassword", (data: any) => {
    setCorrectPassword(data.password);
  });

  useEffect(() => {
    return () => {
      ResetUi();
    };
  }, []);

  const handleInputChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    setPassword(e.target.value);
  };

  const handleKeyPress = (e: React.KeyboardEvent) => {
    if (e.key === 'Enter') {
      if (isChangingPassword) {
        handlePasswordChange();
      } else {
        handlePasswordVerification();
      }
    }
  };

  const handlePasswordVerification = () => {
    const inputPass = String(password || '').trim();
    const correctPass = String(correctPassword || '').trim();
    
    if (inputPass === correctPass && correctPass !== '') {
        fetchNui('passwordSuccessful');
    } else {
        fetchNui('passwordIncorrect');
    }
    ResetUi();
  };

  const handlePasswordChange = () => {
    const newPass = String(password || '').trim();
    if (newPass !== '') {
        fetchNui('passwordChanged', { password: newPass });
    }
    ResetUi();
  };

  const handleButtonClick = (num: number) => {
    setPassword((prevPassword) => prevPassword + num.toString());
  };

  const handleBackspaceClick = () => {
    setPassword((prevPassword) => prevPassword.slice(0, -1));
  };

  const ResetUi = () => {
    setPassword("");
    setCorrectPassword("");
    setVisible(false);
    setIsChangingPassword(false);
  };

  if (!visible) return null;

  return (
    <div className="container flex justify-center items-center h-screen">
      <div className="container-header">
        <h1>{isChangingPassword ? 'Change Password' : 'Keypad'}</h1>
        <p>{isChangingPassword ? 'Enter new password' : 'Enter the code to proceed'}</p>
        <p>Press ESC to close</p>
        <p>Press ENTER to Submit</p>
        <div className="divider-header">
          <div className="line-header" />
        </div>
        <div className="input-container">
          <input
            type="password"
            className="code-header outline-none bg-transparent"
            placeholder={isChangingPassword ? "Enter new password" : "Enter Code"}
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
          <button className="button-header delete-header" onClick={handleBackspaceClick}>
            <FaBackspace />
          </button>
        </div>
      </div>
    </div>
  );
};

export default App;