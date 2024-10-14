import { ethers } from "hardhat";
import { expect } from "chai";
import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { Escrow, MockERC721 } from "../typechain-types";

describe("Escrow", function () {
    async function deployEscrowFixture() {
        const [owner, feeRecipient, seller, buyer, winner, marketPlaceContract, auctionContract] = await ethers.getSigners();
        const feePercentage = 5; // 5% fee for simplicity

        // Deploy Mock ERC721
        const MockERC721 = await ethers.getContractFactory("MockERC721");
        const mockERC721 = await MockERC721.deploy("MockNFT", "MNFT");
        // await mockERC721.deployed();

        const Escrow = await ethers.getContractFactory("Escrow");
        const escrow = await Escrow.deploy(feePercentage, feeRecipient.address);

        // Set the marketplace and auction contract addresses in the escrow contract
        await escrow.updateMarketPlaceContract(marketPlaceContract.address);
        await escrow.updateAuctionContract(auctionContract.address);

        return { escrow, mockERC721, feeRecipient, owner, seller, buyer, winner, marketPlaceContract, auctionContract, feePercentage };
    }

    describe("Deployment", function () {
        it("Should set the correct owner and fee recipient", async function () {
            const { escrow, feeRecipient, owner } = await loadFixture(deployEscrowFixture);
            expect(await escrow.owner()).to.equal(owner.address);
            expect(await escrow.feeRecipient()).to.equal(feeRecipient.address);
        });

        it("Should set the correct fee percentage", async function () {
            const { escrow, feePercentage } = await loadFixture(deployEscrowFixture);
            expect(await escrow.feePercentage()).to.equal(feePercentage);
        });
    });

    describe("Order Escrow", function () {
        it("Should allow deposit for an order", async function () {
            const { escrow, buyer, seller, marketPlaceContract } = await loadFixture(deployEscrowFixture);
            const orderId = 1;
            const orderAmount = ethers.parseEther("1.0");

            // Marketplace contract deposits funds for the order on behalf of buyer
            await escrow.connect(marketPlaceContract).depositForOrder(seller.address, orderAmount, buyer.address, orderId, {
                value: orderAmount,
            });

            const order = await escrow.orderEscrow(buyer.address, seller.address, orderId);
            expect(order.amount).to.equal(orderAmount);
            expect(order.buyer).to.equal(buyer.address);
            expect(order.seller).to.equal(seller.address);
            expect(order.isReceived).to.be.false;
        });

        it("Should release funds to the seller", async function () {
            const { escrow, buyer, seller, feeRecipient, feePercentage, marketPlaceContract } = await loadFixture(deployEscrowFixture);
            const orderId = 1;
            const orderAmount = ethers.parseEther("1.0");

            // Marketplace contract deposits funds for the order on behalf of buyer
            await escrow.connect(marketPlaceContract).depositForOrder(seller.address, orderAmount, buyer.address, orderId, {
                value: orderAmount,
            });

            // // Buyer releases the funds
            // await escrow.connect(buyer).releaseForOrder(buyer.address, seller.address, orderId);

            // const order = await escrow.orderEscrow(buyer.address, seller.address, orderId);
            // expect(order.isReceived).to.be.true;

            // Calculate the expected fee and the seller's payout
            const fee = (orderAmount * BigInt(feePercentage)) / BigInt(100);
            const amountToSeller = orderAmount - fee;

            // Verify balances after release
            await expect(() => escrow.connect(buyer).releaseForOrder(buyer.address, seller.address, orderId))
                .to.changeEtherBalances(
                    [seller, feeRecipient],
                    [amountToSeller, fee]
                );
        });
    });

    describe("Auction Escrow", function () {
        it("Should allow deposit for an auction", async function () {
            const { escrow, seller, winner, auctionContract, mockERC721 } = await loadFixture(deployEscrowFixture);
            const tokenId = 1;
            const winningBid = ethers.parseEther("2.0");

            // Mint and approve the NFT to the escrow contract
            await mockERC721.connect(seller).mint(tokenId);
            await mockERC721.connect(seller).transferFrom(seller, auctionContract, tokenId);
            await mockERC721.connect(auctionContract).transferFrom(auctionContract, escrow.getAddress(), tokenId)

            // Auction contract deposits the winning bid
            await escrow.connect(auctionContract).depositForAuction(mockERC721.getAddress(), tokenId, seller.address, winner.address, winningBid, {
                value: winningBid,
            });

            const auction = await escrow.auctionEscrow(mockERC721.getAddress(), tokenId);
            expect(auction.seller).to.equal(seller.address);
            expect(auction.winner).to.equal(winner.address);
            expect(auction.winningbid).to.equal(winningBid);
            expect(auction.isReceived).to.be.false;
        });

        it("Should release NFT and funds to seller and winner", async function () {
            const { escrow, seller, winner, feeRecipient, feePercentage, auctionContract, mockERC721 } = await loadFixture(deployEscrowFixture);
            const tokenId = 1;
            const winningBid = ethers.parseEther("2.0");

            // Mint and approve the NFT to the escrow contract
            await mockERC721.connect(seller).mint(tokenId);
            await mockERC721.connect(seller).transferFrom(seller, auctionContract, tokenId);
            await mockERC721.connect(auctionContract).transferFrom(auctionContract, escrow.getAddress(), tokenId)

            // Auction contract deposits the winning bid
            await escrow.connect(auctionContract).depositForAuction(mockERC721.getAddress(), tokenId, seller.address, winner.address, winningBid, {
                value: winningBid,
            });

            // Winner releases the NFT and funds
            //////
            // Calculate the fee and seller's payout
            const fee = (winningBid * BigInt(feePercentage)) / BigInt(100);
            const amountToSeller = winningBid - fee;

            // Verify balances after release
            await expect(() => escrow.connect(winner).releaseForAuction(mockERC721.getAddress(), tokenId))
                .to.changeEtherBalances(
                    [seller, feeRecipient],
                    [amountToSeller, fee]
                );
        });
    });

    describe("Owner Functions", function () {
        it("Should allow the owner to update the fee recipient", async function () {
            const { escrow, owner } = await loadFixture(deployEscrowFixture);
            const newFeeRecipient = ethers.Wallet.createRandom().address;

            await escrow.connect(owner).updateFeeRecipient(newFeeRecipient);
            expect(await escrow.feeRecipient()).to.equal(newFeeRecipient);
        });

        it("Should allow the owner to update the fee percentage", async function () {
            const { escrow, owner } = await loadFixture(deployEscrowFixture);
            const newFeePercentage = 10;

            await escrow.connect(owner).updateFeePercentage(newFeePercentage);
            expect(await escrow.feePercentage()).to.equal(newFeePercentage);
        });
    });
});
