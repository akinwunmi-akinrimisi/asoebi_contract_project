import { expect } from "chai";
import { ethers } from "hardhat";
import { time } from "@nomicfoundation/hardhat-network-helpers";
import { AsoEbiAution, MockERC721, MockEscrow } from "../typechain-types";
import { SignerWithAddress } from "@nomicfoundation/hardhat-ethers/signers";
import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";

describe("AsoEbiAution", function () {
    let owner: SignerWithAddress;
    let seller: SignerWithAddress;
    let buyer: SignerWithAddress;
    let bidder: SignerWithAddress;

    const TOKEN_ID = 1;
    const MINIMUM_SELLING_PRICE = ethers.parseEther("1");
    const BID_AMOUNT = ethers.parseEther("1.5");

    async function deployContractsFixture() {
        [owner, seller, buyer, bidder] = await ethers.getSigners();

        // Deploy MockERC721
        const MockERC721 = await ethers.getContractFactory("MockERC721");
        const mockNFT = await MockERC721.deploy("MockNFT", "MNFT");

        // Deploy MockEscrow
        const MockEscrow = await ethers.getContractFactory("MockEscrow");
        const mockEscrow = await MockEscrow.deploy();

        // Deploy AsoEbiAution contract
        const AsoEbiAution = await ethers.getContractFactory("AsoEbiAution");
        const asoEbiAution = await AsoEbiAution.deploy(mockEscrow.target);

        // Setup contracts
        await mockEscrow.updateAuctionContract(asoEbiAution.target);
        await mockNFT.connect(seller).mint(TOKEN_ID);
        await mockNFT.connect(seller).approve(asoEbiAution.target, TOKEN_ID);

        return { asoEbiAution, mockNFT, mockEscrow, seller, bidder, buyer };
    }

    describe("createAuction", function () {
        it("should create an auction successfully", async function () {
            const { asoEbiAution, mockNFT, seller } = await loadFixture(deployContractsFixture);

            const startTime = await time.latest() + 3600; // 1 hour from now
            const endTime = startTime + 86400; // 24 hours after start time

            await expect(asoEbiAution.connect(seller).createAuction(
                mockNFT.target,
                TOKEN_ID,
                MINIMUM_SELLING_PRICE,
                startTime,
                endTime,
                0, // AuctionType.Fabric
                true
            )).to.emit(asoEbiAution, "AuctionCreated")
                .withArgs(mockNFT.target, TOKEN_ID, 0);

            const auction = await asoEbiAution.getAuction(mockNFT.target, TOKEN_ID);
            expect(auction._owner).to.equal(seller.address);
            expect(auction.minimumSellingPrice).to.equal(MINIMUM_SELLING_PRICE);
        });

        it("should revert if not the NFT owner", async function () {
            const { asoEbiAution, mockNFT, buyer } = await loadFixture(deployContractsFixture);

            const startTime = await time.latest() + 3600;
            const endTime = startTime + 86400;

            await expect(asoEbiAution.connect(buyer).createAuction(
                mockNFT.target,
                TOKEN_ID,
                MINIMUM_SELLING_PRICE,
                startTime,
                endTime,
                0,
                true
            )).to.be.revertedWithCustomError(asoEbiAution, "CreateAuction_InvalidOwner");
        });
    });

    describe("placeBid", function () {
        it("should place a bid successfully", async function () {
            const { asoEbiAution, mockNFT, seller, bidder } = await loadFixture(deployContractsFixture);

            const startTime = await time.latest() + 3600;
            const endTime = startTime + 86400;

            await asoEbiAution.connect(seller).createAuction(
                mockNFT.target,
                TOKEN_ID,
                MINIMUM_SELLING_PRICE,
                startTime,
                endTime,
                0,
                true
            );

            await time.increase(3601); // Move time past the start time

            await expect(asoEbiAution.connect(bidder).placeBid(mockNFT.target, TOKEN_ID, { value: BID_AMOUNT }))
                .to.emit(asoEbiAution, "BidPlaced")
                .withArgs(mockNFT.target, TOKEN_ID, bidder.address, BID_AMOUNT);

            const highestBid = await asoEbiAution.getHighestBidder(mockNFT.target, TOKEN_ID);
            expect(highestBid._bidder).to.equal(bidder.address);
            expect(highestBid._bid).to.equal(BID_AMOUNT);
        });

        it("should revert if bid is too low", async function () {
            const { asoEbiAution, mockNFT, seller, bidder } = await loadFixture(deployContractsFixture);

            const startTime = await time.latest() + 3600;
            const endTime = startTime + 86400;

            await asoEbiAution.connect(seller).createAuction(
                mockNFT.target,
                TOKEN_ID,
                MINIMUM_SELLING_PRICE,
                startTime,
                endTime,
                0,
                true
            );

            await time.increase(3601); // Move time past the start time

            const lowBid = ethers.parseEther("0.5");
            await expect(asoEbiAution.connect(bidder).placeBid(mockNFT.target, TOKEN_ID, { value: lowBid }))
                .to.be.revertedWithCustomError(asoEbiAution, "InvalidBid");
        });
    });

    describe("finalizeAuction", function () {
        it("should finalize the auction successfully", async function () {
            const { asoEbiAution, mockNFT, seller, bidder } = await loadFixture(deployContractsFixture);

            const startTime = await time.latest() + 3600;
            const endTime = startTime + 86400;

            await asoEbiAution.connect(seller).createAuction(
                mockNFT.target,
                TOKEN_ID,
                MINIMUM_SELLING_PRICE,
                startTime,
                endTime,
                0,
                true
            );

            await time.increase(3601);
            await asoEbiAution.connect(bidder).placeBid(mockNFT.target, TOKEN_ID, { value: BID_AMOUNT });
            await time.increase(86401);

            await expect(asoEbiAution.connect(seller).finalizeAuction(mockNFT.target, TOKEN_ID))
                .to.emit(asoEbiAution, "AuctionFinalized")
                .withArgs(seller.address, mockNFT.target, TOKEN_ID, bidder.address, BID_AMOUNT);

            const auction = await asoEbiAution.getAuction(mockNFT.target, TOKEN_ID);
            expect(auction._finalized).to.be.true;
        });

        it("should revert if not the auction owner", async function () {
            const { asoEbiAution, mockNFT, buyer, seller } = await loadFixture(deployContractsFixture);

            const startTime = await time.latest() + 3600;
            const endTime = startTime + 86400;

            await asoEbiAution.connect(seller).createAuction(
                mockNFT.target,
                TOKEN_ID,
                MINIMUM_SELLING_PRICE,
                startTime,
                endTime,
                0,
                true
            );

            await time.increase(3601);
            await expect(asoEbiAution.connect(buyer).finalizeAuction(mockNFT.target, TOKEN_ID))
                .to.be.revertedWithCustomError(asoEbiAution, "CheckAuction_InvalidOwner");
        });
    });

    // @akin Add more tests for other functions like cancelAuction, withdrawBid, updateAuctionEndTime, etc.
});
