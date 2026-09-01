package com.ganesh.IKR.repository;
import com.ganesh.IKR.entity.RiskLimit;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.Optional;
public interface RiskLimitRepository extends JpaRepository<RiskLimit, Long> { Optional<RiskLimit> findByUserId(Long userId); }
