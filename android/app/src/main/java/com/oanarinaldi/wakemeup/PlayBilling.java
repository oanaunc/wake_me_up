package com.oanarinaldi.wakemeup;

import android.app.Activity;
import android.os.*;
import com.android.billingclient.api.*;
import java.io.File;
import java.nio.charset.StandardCharsets;
import java.security.*;
import java.security.spec.X509EncodedKeySpec;
import java.util.*;
import org.json.*;

/**
 * Entitlements come from live Play queries and verified receipts; preferences cannot grant access.
 */
public final class PlayBilling implements PurchasesUpdatedListener {
  static final String MONTHLY = "com.oanarinaldi.wakemeup.plus.monthly",
      YEARLY = "com.oanarinaldi.wakemeup.plus.yearly";
  final Activity activity;
  final BillingClient client;
  final Map<String, ProductDetails> products = new LinkedHashMap<>();
  private boolean active = false, connecting = false;
  private long checkedAt = 0;
  boolean loading = true, purchasing = false;
  String message = "";
  Runnable changed = () -> {};
  private final Handler main = new Handler(Looper.getMainLooper());

  PlayBilling(Activity a) {
    activity = a;
    readCache();
    client =
        BillingClient.newBuilder(a)
            .setListener(this)
            .enablePendingPurchases(
                PendingPurchasesParams.newBuilder().enableOneTimeProducts().build())
            .enableAutoServiceReconnection()
            .build();
    connect();
  }

  void connect() {
    if (connecting) return;
    connecting = true;
    loading = true;
    client.startConnection(
        new BillingClientStateListener() {
          public void onBillingSetupFinished(BillingResult r) {
            main.post(
                () -> {
                  connecting = false;
                  loading = false;
                  if (r.getResponseCode() == 0) {
                    load();
                    refresh();
                  } else {
                    message =
                        "Connect to Google Play to load plans. All your standard challenges stay free.";
                    changed.run();
                  }
                });
          }

          public void onBillingServiceDisconnected() {
            main.post(
                () -> {
                  connecting = false;
                  loading = false;
                  changed.run();
                });
          }
        });
  }

  void load() {
    if (!client.isReady()) {
      connect();
      return;
    }
    loading = true;
    changed.run();
    List<QueryProductDetailsParams.Product> list = new ArrayList<>();
    for (String id : Arrays.asList(YEARLY, MONTHLY))
      list.add(
          QueryProductDetailsParams.Product.newBuilder()
              .setProductId(id)
              .setProductType(BillingClient.ProductType.SUBS)
              .build());
    client.queryProductDetailsAsync(
        QueryProductDetailsParams.newBuilder().setProductList(list).build(),
        (r, result) ->
            main.post(
                () -> {
                  loading = false;
                  products.clear();
                  if (r.getResponseCode() == 0)
                    for (ProductDetails p : result.getProductDetailsList())
                      products.put(p.getProductId(), p);
                  message = products.isEmpty() ? "Plans couldn't be loaded. Please try again." : "";
                  changed.run();
                }));
  }

  void refresh() {
    if (!client.isReady()) {
      connect();
      return;
    }
    client.queryPurchasesAsync(
        QueryPurchasesParams.newBuilder().setProductType(BillingClient.ProductType.SUBS).build(),
        (r, list) ->
            main.post(
                () -> {
                  if (r.getResponseCode() != 0) {
                    message = "Couldn't check purchases. Please reconnect and restore.";
                    changed.run();
                    return;
                  }
                  active = false;
                  checkedAt = System.currentTimeMillis();
                  message = "";
                  JSONArray receipts = new JSONArray();
                  for (Purchase p : list) {
                    if (p.getPurchaseState() == Purchase.PurchaseState.PENDING) {
                      message =
                          "Your purchase is pending. Wake Me Up Plus unlocks after Google Play confirms"
                              + " payment.";
                      continue;
                    }
                    if (!valid(p)) continue;
                    active = true;
                    try {
                      receipts.put(
                          new JSONObject()
                              .put("data", p.getOriginalJson())
                              .put("signature", p.getSignature()));
                    } catch (JSONException ignored) {
                    }
                    if (!p.isAcknowledged())
                      client.acknowledgePurchase(
                          AcknowledgePurchaseParams.newBuilder()
                              .setPurchaseToken(p.getPurchaseToken())
                              .build(),
                          ack ->
                              main.post(
                                  () -> {
                                    if (ack.getResponseCode() != 0)
                                      message =
                                          "Purchase confirmation is pending. Please restore"
                                              + " purchases.";
                                    changed.run();
                                  }));
                  }
                  writeCache(receipts);
                  if (active) message = "Wake Me Up Plus is active";
                  changed.run();
                }));
  }

  static boolean known(String id) {
    return MONTHLY.equals(id) || YEARLY.equals(id);
  }

  static boolean verify(String data, String signature, String publicKey) {
    if (data.isEmpty() || signature.isEmpty() || publicKey.isEmpty()) return false;
    try {
      PublicKey key =
          KeyFactory.getInstance("RSA")
              .generatePublic(new X509EncodedKeySpec(Base64.getMimeDecoder().decode(publicKey)));
      Signature verifier = Signature.getInstance("SHA1withRSA");
      verifier.initVerify(key);
      verifier.update(data.getBytes(StandardCharsets.UTF_8));
      return verifier.verify(Base64.getMimeDecoder().decode(signature));
    } catch (Exception e) {
      return false;
    }
  }

  boolean valid(Purchase p) {
    try {
      return p.getPurchaseState() == Purchase.PurchaseState.PURCHASED
          && p.getProducts().stream().anyMatch(PlayBilling::known)
          && activity
              .getPackageName()
              .equals(new JSONObject(p.getOriginalJson()).optString("packageName"))
          && verify(p.getOriginalJson(), p.getSignature(), BuildConfig.PLAY_PUBLIC_KEY);
    } catch (JSONException e) {
      return false;
    }
  }

  static boolean offlineWindowValid(long at, long now) {
    return now >= at && now - at < 3_600_000L;
  }

  boolean hasAccess() {
    return active && offlineWindowValid(checkedAt, System.currentTimeMillis());
  }

  private File cacheFile() {
    return new File(activity.getNoBackupFilesDir(), "play-receipts.json");
  }

  private void readCache() {
    try {
      JSONObject cache =
          new JSONObject(
              new String(
                  new android.util.AtomicFile(cacheFile()).readFully(), StandardCharsets.UTF_8));
      checkedAt = cache.getLong("checkedAt");
      if (!offlineWindowValid(checkedAt, System.currentTimeMillis())) return;
      JSONArray receipts = cache.getJSONArray("receipts");
      for (int i = 0; i < receipts.length(); i++) {
        JSONObject r = receipts.getJSONObject(i);
        if (valid(new Purchase(r.getString("data"), r.getString("signature")))) active = true;
      }
    } catch (Exception ignored) {
    }
  }

  private void writeCache(JSONArray receipts) {
    android.util.AtomicFile file = new android.util.AtomicFile(cacheFile());
    java.io.FileOutputStream out = null;
    try {
      JSONObject cache = new JSONObject().put("checkedAt", checkedAt).put("receipts", receipts);
      out = file.startWrite();
      out.write(cache.toString().getBytes(StandardCharsets.UTF_8));
      file.finishWrite(out);
    } catch (Exception ignored) {
      file.failWrite(out);
    }
  }

  ProductDetails.SubscriptionOfferDetails offer(ProductDetails p) {
    if (p == null || p.getSubscriptionOfferDetails() == null) return null;
    for (var o : p.getSubscriptionOfferDetails()) if (o.getOfferId() == null) return o;
    return null;
  }

  JSONArray catalog() {
    JSONArray result = new JSONArray();
    for (String id : Arrays.asList(YEARLY, MONTHLY)) {
      ProductDetails p = products.get(id);
      var o = offer(p);
      if (o == null) continue;
      var phases = o.getPricingPhases().getPricingPhaseList();
      if (phases.isEmpty()) continue;
      try {
        result.put(
            new JSONObject()
                .put("id", id)
                .put("title", id.equals(YEARLY) ? "Yearly" : "Monthly")
                .put("price", phases.get(phases.size() - 1).getFormattedPrice())
                .put("period", id.equals(YEARLY) ? "year" : "month"));
      } catch (JSONException ignored) {
      }
    }
    return result;
  }

  void buy(String id) {
    if (purchasing || !known(id)) return;
    if (hasAccess()) {
      message = "Wake Me Up Plus is already active. Manage your subscription in Google Play.";
      changed.run();
      return;
    }
    if (BuildConfig.PLAY_PUBLIC_KEY.isEmpty()) {
      message = "Plans are not ready yet. All your standard challenges stay free.";
      changed.run();
      return;
    }
    var p = products.get(id);
    var o = offer(p);
    if (o == null) {
      load();
      return;
    }
    purchasing = true;
    changed.run();
    var item =
        BillingFlowParams.ProductDetailsParams.newBuilder()
            .setProductDetails(p)
            .setOfferToken(o.getOfferToken())
            .build();
    BillingResult r =
        client.launchBillingFlow(
            activity,
            BillingFlowParams.newBuilder()
                .setProductDetailsParamsList(Arrays.asList(item))
                .build());
    if (r.getResponseCode() != 0) {
      purchasing = false;
      message = "Couldn't start checkout. Please try again.";
      changed.run();
    }
  }

  public void onPurchasesUpdated(BillingResult r, List<Purchase> list) {
    main.post(
        () -> {
          purchasing = false;
          if (r.getResponseCode() == 0
              || r.getResponseCode() == BillingClient.BillingResponseCode.ITEM_ALREADY_OWNED)
            refresh();
          else {
            message =
                r.getResponseCode() == BillingClient.BillingResponseCode.USER_CANCELED
                    ? "Purchase canceled."
                    : "Google Play couldn't complete the purchase. Please try again.";
            changed.run();
          }
        });
  }

  void close() {
    client.endConnection();
  }
}
