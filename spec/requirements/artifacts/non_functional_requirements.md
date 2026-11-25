# Non-Functional Requirements

| ID | Name | Description | Significance |
| --- | --- | --- | --- |
| NFR01 | Platform | The application shall run on iPhone with iOS and be written in Swift with SwiftUI. | Must |
| NFR02 | Password storage | The system shall store passwords only as bcrypt hashes and never as plain text. | Must |
| NFR03 | Passkey storage | The system shall store only the public key of a passkey. The private key never leaves the device of the user. | Must |
| NFR04 | Privacy of albums | The system shall never show a private album to anyone except its owner. | Must |
| NFR05 | Data integrity | The system shall reject flavour levels outside 0 to 20, numbers of stars outside 1 to 5 and alcohol percentages outside 0 to 100. | Must |
| NFR06 | Deletion integrity | The system shall delete all data of a user, that depends on it, in one step, when the user deletes its account. | Must |
| NFR07 | Visual design | The screens shall follow the visual design of the project Figma file Main Screens, with range inputs styled as rotary knobs of a DJ console and drinks shown as scrollable tiles, two in a row. | Should |
| NFR08 | Navigation | The application shall have a navigation bar at the bottom of the screen with the Library, Drink Mixer and Albums screens. | Must |
| NFR09 | Search time | The system shall show the results of a search or filter within 1 second for a library of 10,000 drinks. | Should |
| NFR10 | Accessibility | The screens shall support Dynamic Type and VoiceOver labels. | Should |
| NFR11 | Drunk effect | The interface shall show a drunk effect, shifting the 3D glasses, after the user adds a drink to the favourites. | Could |
