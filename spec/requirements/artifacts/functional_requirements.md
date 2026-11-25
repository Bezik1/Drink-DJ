# Functional Requirements

| ID | Name | Description | Significance |
| --- | --- | --- | --- |
| FR01 | Registration | The system shall allow a guest to create an account with a unique username, a unique email and a password. | Must |
| FR02 | Password strength | The system shall show during registration, whether the entered password is strong. | Should |
| FR03 | Login with password | The system shall allow a user to log in with its email and password. | Must |
| FR04 | Login with passkey | The system shall allow a user to log in with a passkey confirmed by Face ID. | Should |
| FR05 | Login error | The system shall inform the person with an error message, when the login data is incorrect. | Must |
| FR06 | Guest mode | The system shall allow a guest to continue without an account and to view only public albums and drinks created by other users. | Must |
| FR07 | Profile | The system shall allow a user to change its username, profile image and password. A change of the password requires the current password and the new password given twice. | Must |
| FR08 | Account deletion | The system shall allow a user to delete its account together with its passkeys, flavour preferences, reviews, liked ingredients and albums. | Must |
| FR09 | Library | The system shall show the most popular drinks and the drinks suggested for the user based on its flavour preferences. | Must |
| FR10 | Search | The system shall allow searching drinks by their name, base spirit and ingredients. | Must |
| FR11 | Filters | The system shall allow filtering drinks by base spirit, by mocktail or alcoholic, and by included or excluded ingredients, and show the number of matching drinks before applying the filters. | Should |
| FR12 | Sorting | The system shall allow sorting drinks by popularity or by average rating. | Should |
| FR13 | Discovery | The system shall show drinks one by one and allow the user to save each of them to the favourites album or to skip it. | Could |
| FR14 | Ingredients matcher | The system shall show the drinks, whose all ingredients are among the ingredients given by the user. | Could |
| FR15 | Drink creation | The system shall allow a user to create a drink with its name, description, photo and ingredients with their amounts and units. | Must |
| FR16 | Drink versions | The system shall save every change of a drink as a new drink version with the next version number, its name, branch, message, date of creation and the version, from which it was made. | Must |
| FR17 | Change of another drink | The system shall save a change of a drink authored by another user as a new drink version authored by the user, without changing the original version. | Must |
| FR18 | Calculated drink values | The system shall calculate the total volume, total alcohol percentage, mocktail status and flavour distribution of every drink version from its ingredients. | Must |
| FR19 | Wanted flavour | The system shall allow the author of a drink version to set its wanted flavour levels and intensity. | Must |
| FR20 | Ingredient suggestions | The system shall calculate a score of every ingredient from the flavour preferences of the user, the wanted flavour of the drink version and the reviews, suggest the ingredients with the highest score and show the score of every ingredient. | Must |
| FR21 | Flavour preferences | The system shall allow a user to set its flavour preferences and to like ingredients, also spirits. | Must |
| FR22 | Reviews | The system shall allow a user, who confirmed that it tasted a drink version, to review it with one to five stars, the perception of sweetness, sourness, bitterness and strength, and notes. | Must |
| FR23 | Albums list | The system shall show the favourites, to check out and your drinks albums and the other albums of the user, each with its icon and number of drinks, and allow searching them by name. | Must |
| FR24 | Album management | The system shall allow a user to create an album with a name, icon and drinks, and later rename it and add or remove its drinks. | Must |
| FR25 | Album sharing | The system shall allow the owner of an album to make it public or private. | Must |
| FR26 | Estimated match | The system shall show the estimated match of a drink version with the flavour preferences of the user. | Should |
| FR27 | Learning from reviews | The system shall update the flavour preferences of a user from its review, when the user allows it. | Should |
| FR28 | Branches | The system shall refuse to continue a branch from a drink version, that is not the latest drink version of that branch. | Must |
| FR29 | Version history | The system shall show the history of the drink versions of a drink and allow opening any of them in the drink mixer. | Should |
| FR30 | Export | The system shall allow a user to export its drink versions, reviews and flavour preferences as a file. | Could |
