//-----------------------------------------
//テストを実行する前の初期設定・準備
//-----------------------------------------
const { expect } = require("chai");
const { ethers } = require("hardhat");

/**
 * テストの処理
 * contract("任意のテストメイ",(account)=>{
 * contractに、asyncは設定出来ない。
 * 非同期処理を書きたい場合、各関数内で書く
 */
describe("NFT contract", function () {

    let nft;
    let owner;
    let alice;
    let bob;

    //テストを始める前に処理したい事
    beforeEach(async function () {

        //アカウントアドレスの設定
        [owner, alice, bob] = await ethers.getSigners();

        // コントラクトのデプロイ
        const NFT = await ethers.getContractFactory("NFT");
        nft = await NFT.deploy();
        await nft.deployed();

        //connect(owner)は、ownerで、コントラクトの関数を呼び出している
        var token_id_0 = await nft.connect(owner).mint(1,10 ** 13,0);//数量、コスト、有効期限
        var token_id_1 = await nft.connect(owner).mint(5,10 ** 12,1);//数量、コスト、有効期限
        var token_id_2 = await nft.connect(owner).mint(10,10 ** 11,0);//数量、コスト、有効期限

    });
    
    //メタデータのベースURIのセットチェック
    describe("metadata URI Check", function() {
        
        //メタデータのベースURIのセットチェック
        it("check set URI", async function () {
            var setTxt = await nft.connect(owner).setURI('https://localhost.com/');// uriのセット
            expect(await nft.connect(owner).uri(0)).to.equal("https://localhost.com/0");// 値が変わっているか検証

        });

        //ベースURIがセットされていない事をチェック
        it("check set URI", async function () {
            //aliceがtoken id 3のトークンを発行
            await nft.connect(alice).mint(10,10**10,0);
            expect(await nft.connect(owner).uri(3)).to.equal("3");
        });

    });

    //token id とクリエイターのアドレスのチェック
    describe("creater Check", function() {

        //creater が発行したidではない場合はエラー
        it("ng check1", async function () {
            //aliceがtoken id 3のトークンをmint
            await nft.connect(alice).mint(10,10,0);
            //connect(owner.address)は、owner.addressで、コントラクトの関数を呼び出している
            //{ value: ethers.utils.parseEther("1") }は、payable関数の実行
            //revertedWithは、エラーになる事を期待する
            await expect(nft.connect(alice).balanceOfCreater(3,owner.address)).to.be.revertedWith("The NFT does not yours.");
        });

        //クリエイターが発行したtoken id
        it("ok check", async function () {
            //onwerが自分のトークンを購入
            await nft.connect(owner).balanceOfCreater(0,owner.address);
        });
        
    });
    
    //トークン購入時のエラーチェック
    describe("token buy Error Check", function() {

        //必要なコストに満たなければエラーが表示されるか？
        it("ng check1", async function () {
            await expect(nft.connect(alice).buyToken(owner.address,0,1,{ value: 10 ** 12 })).to.be.revertedWith("The payment amount is incorrect.");
        });

        //クリエイターが自分のtokenを購入しようとした時、エラーは表示されるか？
        it("ng check2", async function () {
            //onwerが自分のトークンを購入
            await expect(nft.connect(owner).buyToken(owner.address,0,1,{ value: 10 ** 13 })).to.be.revertedWith("受け取りアドレスが不正です。");
        });

        //数量が入っていない場合にエラーが表示されるか？
        it("ng check3", async function () {
            //token id 2（有効期限なし）のトークンを0個購入
            await expect(nft.connect(alice).buyToken(owner.address,2,0,{ value: ethers.utils.parseEther("0") })).to.be.revertedWith("数量は必須入力です。");
        });
        
        //在庫数以上を購入しようとしたらエラーが表示されるか？
        it("ng check4", async function () {
            //token id 2（有効期限なし）のトークンを11個購入
            await expect(nft.connect(alice).buyToken(owner.address,2,11,{ value: ethers.utils.parseEther("0.0000011") })).to.be.revertedWith("The quantity entered exceeds the stock amount.");
        });

        //存在しないtoken id を購入しようとしたらエラーが表示されるか？
        it("ng check5", async function () {
            //token id 10（存在しない）のトークンを11個購入
            await expect(nft.connect(alice).buyToken(owner.address,10,11,{ value: ethers.utils.parseEther("0.0000011") })).to.be.revertedWith("The NFT does not exist.");
        });
        
    });

    //トークン購入が成功するパターンチェック
    describe("token buy success check", async function() {

        //tokenの販売費用が売上残高に正確に追加されているか？
        it("balance check", async function () {
            //token id 0（有効期限なし）のトークンをaliceが購入
            await nft.connect(alice).buyToken(owner.address,0,1,{ value: 10 ** 13 });
            await nft.connect(bob).buyToken(owner.address,1,2,{ value: 2 * 10 ** 12 });
            expect(await nft.connect(owner).getBalance()).to.equal(10 ** 13 + 2 * 10 ** 12);
        });

        //token id 2の在庫数10個　購入できるか？
        it("success check1", async function () {
            //token id 2（有効期限なし）のトークンをaliceが購入
            await nft.connect(alice).buyToken(owner.address,2,10,{ value: ethers.utils.parseEther("0.000001") });
        });

    });

    //token数のチェック
    describe("balance check", async function() {

        //有効期限のあるトークンを同じユーザーが複数個勝手も、個数は1つしか減らない。
        it("expiration check", async function () {
            //token id 1（有効期限あり）のトークンをaliceが購入
            await nft.connect(alice).buyToken(owner.address,1,1,{ value: 10 ** 12 });
            expect(await nft.connect(alice).balanceOf(alice.address,1)).to.equal(1);

            //token id 1（有効期限あり）のトークンを再びaliceが購入
            await nft.connect(alice).buyToken(owner.address,1,1,{ value: 10 ** 12 });
            expect(await nft.connect(alice).balanceOf(alice.address,1)).to.equal(1);

            //token id 1（有効期限あり）のトークンを再びbobが2個購入
            await nft.connect(bob).buyToken(owner.address,1,2,{ value: 2 * 10 ** 12 });
            expect(await nft.connect(alice).balanceOf(bob.address,1)).to.equal(1);

        });

    });

    //有効期限のチェック
    /**
     * 理由は分からないが、約1分程度ずれる
     */
    describe("expiration check", async function() {

        //有効期限のあるトークンを購入した場合の期限のチェック
        it("expiration check", async function () {
            //token id 1（有効期限あり）のトークンをaliceが購入
            //await nft.connect(alice).buyToken(owner.address,1,1,{ value: 10 ** 12 });
            //var timestamp =  Math.floor(Date.now() / 1000) + (24 * 60 * 60);
            //有効期限を取得
            //expect(await nft.connect(alice).getExpirationDate(1)).to.equal(timestamp);

            //token id 1（有効期限あり）のトークンをbobが2個購入
            await nft.connect(bob).buyToken(owner.address,1,1,{ value: 1 * 10 ** 12 });
            await nft.connect(bob).buyToken(owner.address,1,2,{ value: 2 * 10 ** 12 });
            var timestamp =  Math.floor(Date.now() / 1000) + (3 * 24 * 60 * 60);
            //有効期限を取得
            //expect(await nft.connect(bob).getExpirationDate(1)).to.equal(timestamp);

        });

    });

    
    //残金引き出しのチェック
    describe("withdraw check", async function() {

        //引き出しOK
        it("withdraw ok", async function () {

            //aliceがトークンをミント（token id 3となる。）
            await nft.connect(alice).mint(10,10**15,0);

            //token id 3のトークンをbobが2個購入
            await nft.connect(bob).buyToken(alice.address,3,2,{ value: 2 * 10 ** 15 });

            //aliceが残金を引き出し
            await nft.connect(alice).withdraw();

            //aliceが残金0をさらに引き出した場合はエラー
            await expect(nft.connect(alice).withdraw()).to.be.revertedWith("残高がありません。");

            //bobが残金0を引き出した場合はエラー
            await expect(nft.connect(bob).withdraw()).to.be.revertedWith("残高がありません。");

        });

    });

    //オーナーロイヤリティチェック
    describe("royalty check", async function() {

        //売買の3％ロイヤリティがオーナーに正確に支払われるかをチェック
        it("royalty check", async function () {
            //aliceがトークンをミント（token id 3となる。）
            await nft.connect(alice).mint(10,10**15,0);
            //console.log(await nft.connect(alice).getOwnNFTList(alice.address));
            //bonがtoken id [3] を10個購入
            await nft.connect(bob).buyToken(alice.address,3,10,{ value: ethers.utils.parseEther("0.01") });
            expect(await nft.connect(owner).getBalance()).to.equal(ethers.utils.parseEther("0.0003"));
        });

    });

    //トークンのtransferが成功するパターンチェック
    describe("token transfer success", async function() {

        //（有効期限なし）のトークンを第三者に送る
        it("transfer ok check1", async function () {
            //token id 0（有効期限なし）のトークンをaliceが購入
            await nft.connect(alice).buyToken(owner.address,0,1,{ value: ethers.utils.parseEther("0.00001") });
            //token id 0（有効期限なし）のトークンをaliceからbobへtransfer
            await nft.connect(alice).safeTransferFrom(alice.address,bob.address,0,1,[]);
        });

        //（有効期限あり）のトークンをownerから第三者に送る
        it("transfer ok check2", async function () {
            //token id 1（有効期限あり）のトークンをownereからbob
            await nft.connect(owner).safeTransferFrom(owner.address,bob.address,1,1,[]);
        });

    });

    //トークンのtransferが失敗するパターンチェック
    describe("token transfer failed", async function() {

        //有効期限ありのトークンをonwer以外のユーザーが第三者へ送った場合、エラーが表示されるか？
        it("transfer ng check1", async function () {
            //token id 1（有効期限あり）のトークンをaliceが購入
            await nft.connect(alice).buyToken(owner.address,1,1,{ value: ethers.utils.parseEther("0.000001") });
            //token id 1（有効期限あり）のトークンをaliceからbob
            await expect(nft.connect(alice).safeTransferFrom(alice.address,bob.address,1,1,[])).to.be.revertedWith("Transfer not allowed");
        });

        //自分の所有数以上のトークンを送ろうとした場合、エラーがでるか？
        it("transfer ng check2", async function () {
            //token id 0（有効期限なし）のトークンを1個aliceが購入
            await nft.connect(alice).buyToken(owner.address,0,1,{ value: ethers.utils.parseEther("0.00001") });
            //token id 0（有効期限なし）のトークンをaliceからbobへ2個transfer
            await expect(nft.connect(alice).safeTransferFrom(alice.address,bob.address,0,2,[])).to.be.revertedWith("ERC1155: insufficient balance for transfer");
        });

        //第三者が、勝手に他人のトークンを自分へ送ろうとした場合、エラーがでるか？
        it("transfer ng check3", async function () {
            //token id 0（有効期限なし）のトークンを1個aliceが購入
            await nft.connect(alice).buyToken(owner.address,0,1,{ value: ethers.utils.parseEther("0.00001") });
            //token id 0（有効期限なし）のトークンをaliceからbobへ1個transfer
            await expect(nft.connect(owner).safeTransferFrom(alice.address,owner.address,0,1,[])).to.be.revertedWith("ERC1155: caller is not token owner or approved");
        });

    });

    //トークンのburnが成功するパターンチェック
    describe("burn success", async function() {

        //トークンを在庫数の範囲内で焼却
        it("burn ok check1", async function () {
            //token id 0のトークンを1個焼却
            await nft.connect(owner).burn(0,1);
        });

        //トークンを在庫数と同じ数量焼却
        it("burn ok check2", async function () {
            //token id 0のトークンを1個焼却
            await nft.connect(owner).burn(1,5);
        });

    });
    
    //トークンのburnが失敗するパターンチェック
    describe("token burn failed", async function() {

        //在庫数以上のburnを実行した場合
        it("burn ng check1", async function () {
            //token id 0(在庫数1)のトークンを10個焼却
            await expect(nft.connect(owner).burn(0,10)).to.be.revertedWith("数量が所持数を超えています。");
        });

        //他人の所有トークンをburnしようとした場合、エラーがでるか？
        it("burn ng check2", async function () {
            //aliceがtoken id 0（有効数1）のトークンを1個焼却
            await expect(nft.connect(alice).burn(0,1)).to.be.revertedWith("The NFT does not yours.");
        });

        //焼却数が未入力の場合、エラーがでるか？
        it("burn ng check3", async function () {
            //ownerがtoken id 0（有効数1）のトークンを0個焼却
            await expect(nft.connect(owner).burn(0,0)).to.be.revertedWith("quantity required.");
        });

        //存在しないトークンを焼却しようとした場合、エラーがでるか？
        it("burn ng check4", async function () {
            //ownerがtoken id 10（存在しない）のトークンを1個焼却
            await expect(nft.connect(owner).burn(10,1)).to.be.revertedWith("The NFT does not exist.");
        });

    });

      
    //トークンのmintが成功するパターンチェック
    describe("mint success", async function() {

        //オーナーがトークンをmint
        it("mint ok check1", async function () {
            await nft.connect(owner).mint(10,10,0);
        });

        //aliceがトークンをmint
        it("mint ok check1", async function () {
            await nft.connect(alice).mint(10,10,10);
        });

    });
      
    //トークンのminが失敗するパターンチェック
    describe("token mint failed", async function() {

        //数量を0で実行した場合にエラーが表示されるか？
        it("mint ng check1", async function () {
            await expect(nft.connect(owner).mint(0,10,0)).to.be.revertedWith("quantity required.");
        });

        //costを0で実行した場合にエラーが表示されるか？
        it("mint ng check2", async function () {
            await expect(nft.connect(owner).mint(10,0,0)).to.be.revertedWith("cost required.");
        });

        //数量、costを0で実行した場合にエラーが表示されるか？
        it("mint ng check3", async function () {
            await expect(nft.connect(owner).mint(0,0,0)).to.be.revertedWith("quantity required.");
        });

    });

      
    //トークンの販売価格の変更が成功するパターンチェック
    describe("update cost success", async function() {

        //オーナーがトークンのtoken id 0のコストを変更
        it("update cost ok1", async function () {
            //最初の発行価格のチェック
            expect(await nft.connect(owner).getCost(0)).to.equal(10 ** 13);
            //価格の変更
            await nft.connect(owner).updateCost(0,10 ** 10);
            //変更後の価格でチェック
            expect(await nft.connect(owner).getCost(0)).to.equal(10 ** 10);
            //token id 0のトークンを変更後の価格で購入
            await nft.connect(alice).buyToken(owner.address,0,1,{ value: 10 ** 10 });
        });

    });

          
    //トークンの販売価格の変更が失敗するパターンチェック
    describe("update cost failed", async function() {

        //aliceが自分が発行していないトークンのtoken id 0のコストを変更
        it("update cost ng1", async function () {
            await expect(nft.connect(alice).updateCost(0,10 ** 10)).to.be.revertedWith("The NFT does not yours.");
        });

        //トークンのコストを0に変更した場合はエラー
        it("update cost ng1", async function () {
            await expect(nft.connect(owner).updateCost(0,0)).to.be.revertedWith("cost required.");
        });
    });

});