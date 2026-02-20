import { CapacitorTwilioVideo } from '@capgo/capacitor-twilio-video';

window.testEcho = () => {
    const inputValue = document.getElementById("echoInput").value;
    CapacitorTwilioVideo.echo({ value: inputValue })
}
