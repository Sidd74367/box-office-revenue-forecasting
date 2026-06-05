# =============================================================================
# Econ 423 — Final Project
# Predicting Domestic Box Office Revenue Using Time Series Analysis
# Siddharth Capoor (20965060)
# =============================================================================
# HOW TO RUN: set the working directory to the folder containing
#   dataset_1_movies.csv and dataset_2_daily.csv, then run sections in order.
# Each section is clearly labelled and matches a figure/table in the paper
# and presentation.
# =============================================================================

# ---- setup ------------------------------------------------------------------
# Run install packages only if not downloaded
# install.packages(c("readr","dplyr","ggplot2","scales","moments","forecast","tidyr"))
library(readr); library(dplyr); library(ggplot2); library(scales)
library(moments); library(forecast); library(tidyr)

setwd("C:/Users/Siddharth/Documents/econ 423/PROJECT")  # <-- change if needed
movies <- read_csv("dataset_1_movies.csv")
daily  <- read_csv("dataset_2_daily.csv")
daily$date <- as.Date(daily$date)

# =============================================================================
# SECTION 1 — Histograms (distributions, skewness, kurtosis)
# =============================================================================
op_sk <- round(skewness(movies$opening_weekend, na.rm=TRUE), 2)
op_ku <- round(kurtosis(movies$opening_weekend, na.rm=TRUE), 2)
tt_sk <- round(skewness(movies$total_gross,     na.rm=TRUE), 2)
tt_ku <- round(kurtosis(movies$total_gross,     na.rm=TRUE), 2)
cat("Opening: skew=",op_sk," kurt=",op_ku,"\n",sep="")
cat("Total:   skew=",tt_sk," kurt=",tt_ku,"\n",sep="")

p6a <- ggplot(movies, aes(opening_weekend)) +
  geom_histogram(binwidth=25e6, color="black", fill="skyblue", alpha=0.85) +
  scale_x_continuous(labels=label_dollar(scale=1e-6, suffix="M")) +
  coord_cartesian(xlim=c(0,NA)) +
  annotate("text", x=Inf, y=Inf, hjust=1.1, vjust=2.5, size=4,
           label=paste0("Skewness = ",op_sk,"\nKurtosis = ",op_ku)) +
  labs(title="Opening Weekend Distribution", x="Opening Weekend Revenue", y="Frequency") +
  theme_minimal(base_size=14) + theme(plot.title=element_text(face="bold"))

p6b <- ggplot(movies, aes(total_gross)) +
  geom_histogram(binwidth=25e6, color="black", fill="lightcoral", alpha=0.85) +
  scale_x_continuous(labels=label_dollar(scale=1e-6, suffix="M")) +
  coord_cartesian(xlim=c(0,NA)) +
  annotate("text", x=Inf, y=Inf, hjust=1.1, vjust=2.5, size=4,
           label=paste0("Skewness = ",tt_sk,"\nKurtosis = ",tt_ku)) +
  labs(title="Total Revenue Distribution", x="Total Domestic Revenue", y="Frequency") +
  theme_minimal(base_size=14) + theme(plot.title=element_text(face="bold"))
print(p6a); print(p6b)

# =============================================================================
# SECTION 2 — Daily dynamics (first 50 days, all movies)
# =============================================================================
daily_50 <- daily %>% filter(days <= 50)
p7 <- ggplot(daily_50, aes(x=days, y=daily_gross, group=movie)) +
  geom_line(color="steelblue4", alpha=0.22, linewidth=0.5) +
  scale_x_continuous(limits=c(1,50), breaks=seq(0,50,10), expand=c(0,0)) +
  scale_y_continuous(limits=c(0,NA), labels=label_dollar(scale=1e-6, suffix="M"), expand=c(0,0)) +
  labs(title="Daily Box Office Revenue Across All Movies",
       x="Days Since Release", y="Daily Revenue ($M)") +
  theme_minimal(base_size=14) + theme(plot.title=element_text(face="bold"))
print(p7)

# =============================================================================
# SECTION 3 — Log-log scatter (opening vs total)
# =============================================================================
mp <- movies %>% filter(opening_weekend>0, total_gross>0) %>%
  mutate(log_opening=log(opening_weekend), log_total=log(total_gross))
corr_log <- cor(mp$log_opening, mp$log_total)
ll_mod   <- lm(log_total ~ log_opening, data=mp)
r2_ll    <- summary(ll_mod)$r.squared
beta_ll  <- coef(ll_mod)[2]
cat("log-log: corr=",round(corr_log,3)," R2=",round(r2_ll,3),
    " elasticity=",round(beta_ll,3),"\n",sep="")

p8 <- ggplot(mp, aes(log_opening, log_total)) +
  geom_point(size=2.8, alpha=0.75, color="steelblue4") +
  geom_smooth(method="lm", se=FALSE, color="firebrick", linewidth=1) +
  annotate("text", x=min(mp$log_opening)+0.5, y=max(mp$log_total)-0.6,
           hjust=0, size=4, color="gray30",
           label=paste0("Correlation = ",round(corr_log,3),
                        "\nR\u00b2 = ",round(r2_ll,3),
                        "\nElasticity = ",round(beta_ll,3))) +
  labs(title="Opening Weekend vs Total Revenue (Log-Log)",
       x="Log Opening Weekend Revenue", y="Log Total Domestic Revenue") +
  theme_minimal(base_size=14) + theme(plot.title=element_text(face="bold"))
print(p8)

# =============================================================================
# SECTION 4 — Why not difference (ACF + variance comparison)
# =============================================================================
avg_daily <- daily_50 %>% group_by(days) %>%
  summarise(avg_gross=mean(daily_gross, na.rm=TRUE), .groups="drop") %>%
  mutate(log_g=log(avg_gross))
y    <- avg_daily$log_g
d1y  <- diff(y); d2y <- diff(d1y)
var_tbl <- data.frame(Series=c("Raw log","1st diff","2nd diff"),
                      Variance=round(c(var(y), var(d1y), var(d2y)), 4))
print(var_tbl)

par(mfrow=c(1,2))
acf(y,   main="ACF: Raw log revenue")
acf(d1y, main="ACF: First difference")
par(mfrow=c(1,1))

# =============================================================================
# SECTION 5 — Cross-sectional regression (main model)
#             + extension with budget and runtime controls
# =============================================================================
mp$log_open_fr <- mp$log_opening * mp$franchise
cs_main <- lm(log_total ~ log_opening + franchise + log_open_fr, data=mp)
summary(cs_main)

# Extended model with new controls
mp_ext <- mp %>% filter(!is.na(budget), !is.na(runtime)) %>%
  mutate(log_budget = log(budget))
cs_ext <- lm(log_total ~ log_opening + franchise + log_open_fr + log_budget + runtime,
             data=mp_ext)
summary(cs_ext)

# =============================================================================
# SECTION 6 — Week 1 vs Week 2 vs Week 3 vs Day 1 predictive power
# =============================================================================
wk <- daily %>%
  group_by(movie) %>%
  summarise(w1 = sum(daily_gross[days>=1  & days<=7]),
            w2 = sum(daily_gross[days>=8  & days<=14]),
            w3 = sum(daily_gross[days>=15 & days<=21]),
            d1 = sum(daily_gross[days==1]), .groups="drop") %>%
  left_join(movies %>% select(movie, total_gross, franchise), by="movie") %>%
  filter(w1>0, w2>0, w3>0, d1>0, total_gross>0)

single <- function(var) {
  m <- lm(log(total_gross) ~ log(wk[[var]]), data=wk)
  s <- summary(m)
  c(beta=coef(m)[2], p=s$coefficients[2,4], R2=s$r.squared, n=nrow(wk))
}
res_tbl <- rbind(
  "Day 1"  = single("d1"),
  "Week 1" = single("w1"),
  "Week 2" = single("w2"),
  "Week 3" = single("w3")
)
print(round(res_tbl, 4))

# Combined model: which weeks add incremental information?
wcomb <- lm(log(total_gross) ~ log(w1) + log(w2) + log(w3), data=wk)
summary(wcomb)

# =============================================================================
# SECTION 7 — Detrending regression + residual diagnostics
# =============================================================================
avg_daily$dow <- factor((avg_daily$days - 1) %% 7)
ts_reg <- lm(log_g ~ days + dow, data=avg_daily)
summary(ts_reg)
avg_daily$resid <- residuals(ts_reg)

acf(avg_daily$resid, main="ACF: Regression residuals")
Box.test(avg_daily$resid, lag=14, type="Ljung-Box")

# =============================================================================
# SECTION 8 — Residual-dynamics model comparison (AIC/BIC)
# =============================================================================
y <- avg_daily$resid
fit_list <- list(
  `AR(1)`   = arima(y, order=c(1,0,0)),
  `AR(2)`   = arima(y, order=c(2,0,0)),
  `MA(1)`   = arima(y, order=c(0,0,1)),
  `ARMA(1,1)` = arima(y, order=c(1,0,1)),
  `ARMA(2,1)` = arima(y, order=c(2,0,1)),
  `ARMA(1,2)` = arima(y, order=c(1,0,2))
)
mod_tbl <- data.frame(
  Model = names(fit_list),
  AIC = sapply(fit_list, AIC),
  BIC = sapply(fit_list, BIC))
auto <- auto.arima(y)
mod_tbl <- rbind(mod_tbl, data.frame(Model="auto.arima", AIC=AIC(auto), BIC=BIC(auto)))
print(mod_tbl[order(mod_tbl$AIC),])

# =============================================================================
# SECTION 9 — Full hybrid model forecast comparison
# =============================================================================
sample_mv <- c("M3GAN", "Shazam! Fury of the Gods")
cat("Test movies:", sample_mv, "\n")

run_hybrid <- function(mov, ar_order=NULL, use_auto=FALSE) {
  df <- daily %>% filter(movie==mov, daily_gross>0) %>% arrange(days) %>%
    mutate(log_g=log(daily_gross), dow=factor((days-1)%%7))
  tr <- df %>% filter(days<=40); te <- df %>% filter(days>40, days<=50)
  if (nrow(te)==0) return(NULL)
  if (length(unique(tr$dow))<2) reg <- lm(log_g ~ days, data=tr) else
    reg <- lm(log_g ~ days + dow, data=tr)
  tr_res <- residuals(reg)
  arm <- tryCatch(
    if (use_auto) auto.arima(tr_res) else arima(tr_res, order=ar_order),
    error=function(e) NULL)
  if (is.null(arm)) return(NULL)
  h <- nrow(te)
  fc <- as.numeric(if (use_auto) forecast(arm, h=h)$mean
                   else predict(arm, n.ahead=h)$pred)
  reg_te <- predict(reg, newdata=te)
  pred   <- reg_te + fc
  data.frame(movie=mov, days=te$days, actual=te$log_g, pred=pred)
}

candidates <- list(
  "AR(1)"     = c(1,0,0),
  "AR(2)"     = c(2,0,0),
  "MA(1)"     = c(0,0,1),
  "ARMA(1,1)" = c(1,0,1),
  "ARMA(2,1)" = c(2,0,1),
  "ARMA(1,2)" = c(1,0,2)
)

all_rows <- list(); fc_plot_df <- list()
for (name in names(candidates)) {
  for (mv in sample_mv) {
    r <- run_hybrid(mv, ar_order=candidates[[name]])
    if (!is.null(r)) {
      rmse <- sqrt(mean((r$actual-r$pred)^2))
      mae  <- mean(abs(r$actual-r$pred))
      all_rows[[length(all_rows)+1]] <- data.frame(
        Model=paste0("Regression + ",name), Movie=mv, RMSE=rmse, MAE=mae)
      if (name=="AR(1)") {
        r$Model <- name; fc_plot_df[[length(fc_plot_df)+1]] <- r
      }
    }
  }
}
# auto.arima
for (mv in sample_mv) {
  r <- run_hybrid(mv, use_auto=TRUE)
  if (!is.null(r)) {
    all_rows[[length(all_rows)+1]] <- data.frame(
      Model="Regression + auto.arima", Movie=mv,
      RMSE=sqrt(mean((r$actual-r$pred)^2)),
      MAE=mean(abs(r$actual-r$pred)))
  }
}

forecast_table <- do.call(rbind, all_rows)
print(forecast_table)

summary_tbl <- forecast_table %>% group_by(Model) %>%
  summarise(avg_RMSE=mean(RMSE), avg_MAE=mean(MAE)) %>% arrange(avg_RMSE)
print(summary_tbl)

# Plot forecast vs actual for the WINNING model (AR(1))
fc_df <- do.call(rbind, fc_plot_df)
p17 <- ggplot(fc_df, aes(x=days)) +
  geom_line(aes(y=actual, color="Actual"), linewidth=1) +
  geom_line(aes(y=pred,   color="Predicted"), linewidth=1, linetype="dashed") +
  facet_wrap(~movie, scales="free_y") +
  scale_color_manual(values=c(Actual="steelblue4", Predicted="firebrick")) +
  labs(title="Forecast vs Actual (log daily revenue) — Regression + AR(1)",
       x="Days since release", y="log(Daily revenue)", color="") +
  theme_minimal(base_size=13) + theme(plot.title=element_text(face="bold"))
print(p17)


# =============================================================================
# END
# =============================================================================
