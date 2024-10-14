# ASO EBI MARKETPLACE SMART CONTRACT

A decentralized platform for fashion, the Aso Ebi Marketplace links local fabric vendors, designers, and buyers. Users can order personalized garments, buy and sell fabrics, and tokenize high-end fashion items as NFTs. Smart contracts are used by the platform to provide safe transactions, automatic escrow payments, and NFT-backed ownership proof for custom clothing.

The Solidity smart contracts that drive the Aso Ebi Marketplace are housed in this repository and manage the following features:

* Decentralized fabric and fashion marketplace
* Bespoke clothing orders
* NFT-backed garments and fashion collectibles
* Secure, escrow-based payments
* Chainlink oracles for real-world data integration

## Contract Overview ##

1. Marketplace Contract

    Handles buying, and selling of fabrics and designs.
    Allows buyers to place custom clothing orders with detailed specifications.

2. Escrow Contract

    Manages payments held in escrow during transactions.
    Ensures funds are released only after the buyer confirms receipt of the product.

3. NFT Contract
    Mints NFTs for unique fashion pieces, giving buyers digital proof of ownership.
    Allows for Listing, resale of exclusive fashion collectibles.

4. Oracle Contract

    Uses Chainlink price feeds to fetch up-to-date pricing and shipping information.
    Integrates with external data sources via oracles for transparency and accuracy. 

```shell
git clone https://github.com/Web3bidgeAsoOke/asoebi_contract
cd asoebi_contract

npm install

```

### License ###

The MIT License governs the use of this project. For further information, see the LICENSE file.

By integrating blockchain technology and Chainlink oracles, the Aso Ebi Marketplace aims to bring transparency, security, and a decentralized fashion experience to the global market. Happy coding!
